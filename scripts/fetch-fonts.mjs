// 빌드할 때 npm에서 고운바탕·고운돋움 폰트를 받아 www/fonts 에 넣는다.
// 앱이 인터넷 없이도 같은 글꼴로 보이게 하려는 용도.
import { execSync } from 'node:child_process';
import { mkdirSync, readdirSync, copyFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const tmp = 'build-fonts';
mkdirSync(tmp, { recursive: true });
execSync('npm init -y && npm i @fontsource/gowun-batang@5 @fontsource/gowun-dodum@5', { cwd: tmp, stdio: 'inherit' });

const out = 'www/fonts';
mkdirSync(out, { recursive: true });
const faces = [
  { pkg: 'gowun-batang', family: 'Gowun Batang', weight: 700 },
  { pkg: 'gowun-dodum', family: 'Gowun Dodum', weight: 400 },
];
let css = '';
for (const f of faces) {
  const dir = join(tmp, 'node_modules/@fontsource', f.pkg);
  const files = join(dir, 'files');
  for (const name of readdirSync(files)) {
    if (name.endsWith('.woff2') && name.includes(`-${f.weight}-normal`)) copyFileSync(join(files, name), join(out, name));
  }
  // fontsource 의 글꼴별 CSS(유니코드 범위 분할)를 그대로 쓰되 경로만 바꾼다
  const cssFile = join(dir, `${f.weight}.css`);
  if (existsSync(cssFile)) {
    const { readFileSync } = await import('node:fs');
    css += readFileSync(cssFile, 'utf8')
      .replace(/url\(\.\/files\/([^)]+\.woff2)\)/g, 'url(./$1)')
      .replace(/,\s*url\([^)]+\.woff\)\s*format\('woff'\)/g, '');
  }
}
writeFileSync(join(out, 'fonts.css'), css);
console.log('fonts ready:', readdirSync(out).length, 'files');
