"""OpenGameArt 페이지(라이선스·작가 확인용)만 받아 저장"""
import os, sys, re, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
src = open(os.path.join(os.path.dirname(__file__), 'fetch_assets.py')).read()
slugs = re.findall(r"'([a-z0-9-]+)'", src[src.index('OGA = {'):src.index('manifest = []')])
for s in slugs:
    try:
        req = urllib.request.Request('https://opengameart.org/content/' + s, headers={'User-Agent': 'Mozilla/5.0'})
        h = urllib.request.urlopen(req, timeout=60).read().decode('utf-8', 'replace')
        open(os.path.join(OUT, s + '.html'), 'w').write(h); print('ok', s)
    except Exception as e: print('x', s, e)
