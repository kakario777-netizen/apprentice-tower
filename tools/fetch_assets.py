"""빌드 서버에서 무료(CC0 등) 에셋 내려받기 → asset-src 가지로 올림.
OpenGameArt 페이지에서 라이선스와 첨부 파일을 읽고, Poly Haven API 로 질감(1K)을 받는다."""
import os, re, json, sys, zipfile, urllib.request, html
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
UA = {'User-Agent': 'Mozilla/5.0 (asset fetch for apprentice-tower)'}
def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        d = r.read()
    return d if binary else d.decode('utf-8', 'replace')

OGA = {
  'models': ['stylized-nature-megakit', 'fantasy-props-megakit'],
  'music': ['loopable-dungeon-ambience', 'dungeon-ambience', 'dark-cavern-ambient', 'dark-the-whispering-shadows-dungeon', 'sinister-loop',
            'medieval-the-old-tower-inn', 'medieval-kings-feast', 'medieval-town', 'magestic-dreams', 'battle-theme-0', 'colossal-boss-battle-theme',
            'boss-theme', 'medieval-defeat-theme', 'cc0-cinematic-music', 'heroic-demise-updated-version', 'the-dark-castle', 'dark-ambient',
            'crypt-loop', 'cave-theme', 'town-theme-rpg', 'village', 'fantasy-dungeon-music', 'dungeon-theme', 'catacombs'],
  'sfx': ['50-rpg-sound-effects', 'rpg-sound-pack', '80-cc0-rpg-sfx', 'interface-sounds', 'magic-sounds', 'spell-sounds', 'ice-spells', 'magic-spell-sfx',
          'fire-evil-spell', 'ice-electricity-magic', 'freeze-spell-0', 'spell-effects-by-starsteelgaming', 'cc0-sounds-library',
          '51-ui-sound-effects-buttons-switches-and-clicks', 'impact-sounds', 'inventory-sound-effects', 'coin-sounds', '8-bit-sound-effects-library',
          'level-up-sound-effects', 'fire-crackling-ambience', 'swish-bamboo-stick-weapon-swhoshes', 'bone-crushing', 'monster-sound-effects-pack',
          '100-cc0-sfx', 'rpg-sfx', 'potion-drinking', 'bubbles-pop', 'door-open-close'],
}
manifest = []
for cat, slugs in OGA.items():
    for slug in slugs:
        url = 'https://opengameart.org/content/' + slug
        try:
            page = get(url)
        except Exception as e:
            manifest.append({'cat': cat, 'slug': slug, 'error': str(e)}); print('skip', slug, e); continue
        title = re.search(r'<title>(.*?)</title>', page, re.S)
        lic = re.findall(r'field-name-field-art-licenses.*?</div>\s*</div>\s*</div>', page, re.S)
        lics = re.findall(r'title="([^"]*(?:CC|GPL|OGA)[^"]*)"', lic[0]) if lic else []
        author = re.search(r'field-name-author-submitter.*?<a[^>]*>(.*?)</a>', page, re.S)
        desc = re.search(r'field-name-body.*?<div class="field-item[^"]*">(.*?)</div>', page, re.S)
        files = sorted(set(re.findall(r'https://opengameart\.org/sites/default/files/[^"\'<> ]+\.(?:zip|ogg|wav|mp3|flac)', page)))
        ent = {'cat': cat, 'slug': slug, 'title': html.unescape(title.group(1).split('|')[0].strip()) if title else slug,
               'licenses': lics, 'author': html.unescape(re.sub('<.*?>', '', author.group(1))) if author else '',
               'desc': html.unescape(re.sub('<.*?>', ' ', desc.group(1)))[:400] if desc else '', 'files': []}
        d = os.path.join(OUT, cat, slug); os.makedirs(d, exist_ok=True)
        for f in files:
            name = urllib.request.unquote(f.rsplit('/', 1)[1])
            try:
                data = get(f, True)
            except Exception as e:
                print('fail', f, e); continue
            p = os.path.join(d, name)
            open(p, 'wb').write(data); ent['files'].append(name)
            if name.endswith('.zip'):
                with zipfile.ZipFile(p) as z:
                    for n in z.namelist():
                        low = n.lower()
                        keep = (cat != 'models') or ('gltf' in low or low.endswith(('.gltf', '.glb', '.bin', '.png', '.jpg')))
                        if cat == 'models' and ('fbx' in low or '/obj/' in low or low.endswith(('.fbx', '.obj', '.mtl', '.blend'))): keep = False
                        if keep and not n.endswith('/'):
                            z.extract(n, d)
                os.remove(p)
        manifest.append(ent); print('ok', slug, lics, len(ent['files']))

# Poly Haven 질감(1K jpg: 색·노멀·거칠기·AO)
PH = ['stone_tiles_02', 'stone_tiles', 'stone_brick_wall_001', 'stone_wall', 'stone_wall_02', 'stone_wall_04', 'rustic_stone_wall', 'rock_wall_12',
      'rock_wall_05', 'red_sandstone_wall', 'embedded_rock_floor', 't_brick_floor_002', 'tiled_floor_001', 'large_sandstone_blocks', 'cobblestone_floor_001',
      'castle_brick_07', 'castle_brick_02_red', 'medieval_blocks_02', 'medieval_blocks_03', 'dark_brick_wall', 'forrest_ground_01', 'aerial_grass_rock',
      'brown_mud_leaves_01', 'rocky_terrain_02', 'grass_path_2', 'cobblestone_05', 'mossy_cobblestone', 'broken_wall', 'old_planks_02', 'black_stone_floor',
      'gravel_floor_02', 'cobble_floor_04', 'stone_floor', 'worn_tile_floor', 'herringbone_brick', 'brick_floor_003', 'castle_wall_slates', 'rock_wall_08']
try:
    allt = json.loads(get('https://api.polyhaven.com/assets?t=textures'))
    json.dump({k: {'name': v.get('name'), 'categories': v.get('categories'), 'tags': v.get('tags')} for k, v in allt.items()},
              open(os.path.join(OUT, 'polyhaven_index.json'), 'w'), ensure_ascii=False)
except Exception as e:
    allt = {}; print('ph index fail', e)
for tid in PH:
    try:
        fj = json.loads(get('https://api.polyhaven.com/files/' + tid))
    except Exception as e:
        manifest.append({'cat': 'tex', 'slug': tid, 'error': str(e)}); continue
    d = os.path.join(OUT, 'tex', tid); os.makedirs(d, exist_ok=True); got = []
    for key, short in [('Diffuse', 'diff'), ('nor_gl', 'nor'), ('Rough', 'rough'), ('AO', 'ao')]:
        try:
            u = fj[key]['1k']['jpg']['url']
            open(os.path.join(d, '%s_%s.jpg' % (tid, short)), 'wb').write(get(u, True)); got.append(short)
        except Exception as e:
            print('tex miss', tid, key, e)
    manifest.append({'cat': 'tex', 'slug': tid, 'licenses': ['CC0'], 'author': 'Poly Haven', 'files': got}); print('tex', tid, got)
json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w'), ensure_ascii=False, indent=1)
