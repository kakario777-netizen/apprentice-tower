"""OpenGameArt 페이지 몇 개만 받아 보기(라이선스·설명·첨부) → asset-probe 가지
python3 tools/fetch_probe.py OUT"""
import os, re, sys, json, zipfile, urllib.request, html
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
UA = {'User-Agent': 'Mozilla/5.0 (asset fetch for apprentice-tower)'}
SLUGS = ['evil-rabbit-creature', 'generic-rabbit-obj', 'rabbit-0', 'low-poly-rabbit', '5-low-poly-animals']
def get(url, binary=False):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        d = r.read()
    return d if binary else d.decode('utf-8', 'replace')
man = []
for slug in SLUGS:
    try: page = get('https://opengameart.org/content/' + slug)
    except Exception as e:
        man.append({'slug': slug, 'error': str(e)}); continue
    lic = re.findall(r'field-name-field-art-licenses.*?</div>\s*</div>\s*</div>', page, re.S)
    lics = re.findall(r'title="([^"]*(?:CC|GPL|OGA)[^"]*)"', lic[0]) if lic else []
    author = re.search(r'field-name-author-submitter.*?<a[^>]*>(.*?)</a>', page, re.S)
    desc = re.search(r'field-name-body.*?<div class="field-item[^"]*">(.*?)</div>', page, re.S)
    imgs = sorted(set(re.findall(r'https://opengameart\.org/sites/default/files/styles/medium/public/[^"\'<> ]+\.(?:png|jpg|gif)', page)))
    files = sorted(set(re.findall(r'https://opengameart\.org/sites/default/files/[^"\'<> ]+\.(?:zip|blend|obj|glb|gltf|fbx|dae|png|jpg|7z|rar|mtl)', page)))
    d = os.path.join(OUT, slug); os.makedirs(d, exist_ok=True); got = []
    for f in files + imgs:
        if '/styles/' in f and f not in imgs: continue
        name = urllib.request.unquote(f.rsplit('/', 1)[1])
        try: data = get(f, True)
        except Exception as e: continue
        if len(data) > 60_000_000: continue
        open(os.path.join(d, name), 'wb').write(data); got.append(name)
        if name.endswith('.zip'):
            try:
                with zipfile.ZipFile(os.path.join(d, name)) as z: z.extractall(os.path.join(d, name[:-4]))
            except Exception: pass
    man.append({'slug': slug, 'licenses': lics, 'author': html.unescape(re.sub('<.*?>', '', author.group(1))) if author else '',
                'desc': html.unescape(re.sub('<.*?>', ' ', desc.group(1)))[:800] if desc else '', 'files': got})
json.dump(man, open(os.path.join(OUT, 'manifest.json'), 'w'), ensure_ascii=False, indent=1)
print(json.dumps(man, ensure_ascii=False, indent=1))
