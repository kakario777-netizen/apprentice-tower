"""질감 그림에서 노멀맵(요철) 만들기: godot/ui/tex_*.png → tex_*_n.png"""
import os, glob
import numpy as np
from PIL import Image, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'ui')
for p in glob.glob(os.path.join(OUT, 'tex_*.png')):
    if p.endswith('_n.png'): continue
    im = Image.open(p).convert('L').filter(ImageFilter.GaussianBlur(1.2))
    h = np.asarray(im, dtype=np.float32) / 255.0
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 4.0
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 4.0
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * .5 + .5) * 255).astype(np.uint8)).save(p[:-4] + '_n.png')
    print(os.path.basename(p))
