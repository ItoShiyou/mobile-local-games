"""Cuts the Codex-generated turnaround sheet (magenta background) into the four
cat sprites in assets/art/. Usage: python3 tool/make_cat_sprites.py cat_sheet.png
The sheet comes from tool/cat_sheet_prompt.txt (codex exec, image generation).
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

src = sys.argv[1]
a = np.asarray(Image.open(src).convert('RGB')).astype(float)
mag = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
alpha = np.where(mag > 150, 0, np.where(mag < 90, 1, (150 - mag) / 60))
rgb = a.copy()
spill = np.clip(mag, 0, None) * (alpha < 1)
rgb[..., 0] -= spill * .5
rgb[..., 2] -= spill * .5
A = Image.fromarray((alpha * 255).astype('uint8'))
A = A.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(.6))
sheet = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.asarray(A)]).astype('uint8'))

cols = (np.asarray(A) > 127).sum(0) > 0
groups, s = [], None
for i, c in enumerate(cols):
    if c and s is None:
        s = i
    if not c and s is not None:
        if i - s > 40:
            groups.append((s, i))
        s = None
if s is not None:
    groups.append((s, len(cols)))
assert len(groups) == 4, groups

crops = []
for x0, x1 in groups:
    c = sheet.crop((max(x0 - 10, 0), 0, x1 + 10, sheet.height))
    crops.append(c.crop(c.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()))
H, W = max(c.height for c in crops), max(c.width for c in crops)
CW, CH = W + 20, H + 10
for name, c in zip(['down', 'up', 'right', 'happy'], crops):
    cv = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    cv.paste(c, ((CW - c.width) // 2, CH - c.height - 4), c)
    cv.resize((CW * 2 // 3, CH * 2 // 3), Image.LANCZOS).save(f'assets/art/cat_{name}.png')
