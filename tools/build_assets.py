"""Prepare embedded pixel assets from documented arcade screenshots.

Build-time utility only. The executable decodes/draws every asset in assembly.
References and limitations are documented in docs/REFERENCES.md.
"""
from pathlib import Path
import math
import struct
from PIL import Image, ImageDraw, ImageOps
from collections import Counter, deque

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "assets" / "reference"
OUT = ROOT / "assets" / "generated"
OUT.mkdir(parents=True, exist_ok=True)
start = Image.open(REF / "native-start.png").convert("RGBA")
race = Image.open(REF / "native-race.png").convert("RGBA")
crash = Image.open(REF / "native-curve.png").convert("RGBA")
title = Image.open(REF / "native-title.png").convert("RGBA")
BG = {(0, 0, 247), (0, 214, 148), (82, 99, 99), (99, 99, 99), (0, 164, 148),
      (0, 148, 148), (0, 181, 148), (0, 197, 148)}

def save(name, image):
    image = image.convert("RGBA")
    if name.startswith(('bike_', 'rival_', 'tumble_')) or name in ('upright', 'fallen'):
        # Slightly chunkier character art on a stable 2x2 source-pixel grid.
        width, height = image.size
        image = image.resize((max(1, width//2), max(1, height//2)),
                             Image.Resampling.NEAREST).resize((width,height),
                             Image.Resampling.NEAREST)
    data = bytearray(struct.pack("<II", *image.size))
    for r, g, b, a in image.get_flattened_data():
        data += struct.pack("<I", (r << 16) | (g << 8) | b if a else 0xFF000000)
    (OUT / (name + ".bin")).write_bytes(data)
    image.save(OUT / (name + ".png"))

def cut(source, box, background=BG):
    result = source.crop(box)
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = result.getpixel((x, y))
            if (r, g, b) in background:
                result.putpixel((x, y), (0, 0, 0, 0))
    return result

clean_title = title.copy()
ImageDraw.Draw(clean_title).rectangle((100,148,226,201), fill=(0,0,0))
ImageDraw.Draw(clean_title).rectangle((212,198,319,213), fill=(0,0,0))
save("title", clean_title)
save("logo", cut(title, (24,32,306,137), {(0,0,0)}))
pixel_start = start.copy()
for box in [(152,137,176,161), (65,136,94,174), (107,143,145,203),
            (185,145,217,203), (229,139,260,177), (24,155,75,224),
            (244,158,295,224), (146,151,181,224)]:
    model = start.crop(box)
    width, height = model.size
    model = model.resize((max(1,width//2),max(1,height//2)),
                         Image.Resampling.NEAREST).resize((width,height),
                         Image.Resampling.NEAREST)
    pixel_start.paste(model, box[:2])
save("start", pixel_start)
for name, filename in [('scores','native-scores.png'),('over','native-over.png')]:
    image = Image.open(REF / filename).convert('RGBA')
    if name == 'scores':
        ImageDraw.Draw(image).rectangle((212,198,319,213), fill=image.getpixel((0,198)))
    save(name, image)
# Isolated source pixels. Pixels matching flat track/grass colors become alpha.
upright = cut(start, (146, 151, 181, 224))
lean = cut(race, (140, 160, 197, 224))
save("upright", upright)

# Reconstruct intermediate poses with distinct body and chassis transforms.
# Endpoints use screenshot pixels. Intermediate poses/timing are approximations.
for pose in range(-3, 4):
    canvas = Image.new("RGBA", (80, 80))
    amount = abs(pose)
    if amount == 3:
        image = lean if pose > 0 else ImageOps.mirror(lean)
        canvas.alpha_composite(image, ((80 - image.width) // 2, 80 - image.height))
    elif amount == 0:
        canvas.alpha_composite(upright, (22, 7))
    else:
        # Chassis leans about its rear tyre, rider moves farther toward the turn.
        sign = 1 if pose > 0 else -1
        chassis = upright.crop((0, 33, 35, 73)).rotate(-sign * amount * 7,
                    Image.Resampling.NEAREST, expand=True)
        body = upright.crop((0, 0, 35, 36)).rotate(-sign * amount * 10,
                    Image.Resampling.NEAREST, expand=True)
        canvas.alpha_composite(chassis, ((80 - chassis.width) // 2, 80 - chassis.height))
        canvas.alpha_composite(body, ((80 - body.width) // 2 + sign * amount * 3, 7 + amount * 4))
    save(f"bike_{pose+3}", canvas)

# Replace intermediate reconstructions with actual observed arcade video poses.
# Palette snapping removes H.264 ringing while retaining nearest source pixels.
colors = Counter()
for image in [start, race, crash]:
    colors.update(image.convert('RGB').get_flattened_data())
palette = Image.new('P', (1, 1))
rgb = list(colors)[:256]
palette.putpalette([channel for color in rgb for channel in color] + [0]*(768-3*len(rgb)))

def video_sprite(name):
    source = Image.open(REF / name).convert('RGB').quantize(palette=palette,
                    dither=Image.Dither.NONE).convert('RGBA')
    im = cut(source, (116, 144, 212, 224))
    # Keep the largest connected foreground object, discarding road markings.
    remaining = {(x,y) for y in range(im.height) for x in range(im.width)
                 if im.getpixel((x,y))[3]}
    groups = []
    while remaining:
        seed = remaining.pop(); group = {seed}; queue = deque([seed])
        while queue:
            x,y = queue.popleft()
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]:
                n = (x+dx,y+dy)
                if n in remaining:
                    remaining.remove(n); group.add(n); queue.append(n)
        groups.append(group)
    keep = max(groups, key=len)
    for y in range(im.height):
        for x in range(im.width):
            if (x,y) not in keep:
                im.putpixel((x,y),(0,0,0,0))
    canvas = Image.new('RGBA',(80,80))
    canvas.alpha_composite(im,(-4,0))
    return canvas

for pose, name in {0:'lean-30.png',1:'lean-32.png',2:'lean-29.png',3:'straight.png',
                   4:'lean-12.png',5:'lean-0.png'}.items():
    save(f'bike_{pose}',video_sprite(name))

clean_upright = Image.open(OUT/'bike_3.png').convert('RGBA')
upright = clean_upright.crop(clean_upright.getbbox())

for color, target in enumerate([(0, 189, 247), (0, 247, 0), (247, 214, 0)]):
    for pose in range(7):
        im = Image.open(OUT / f"bike_{pose}.png").convert("RGBA")
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = im.getpixel((x, y))
                if a and r > 110 and r > g * 1.7 and r > b * 1.4:
                    strength = r / 247
                    im.putpixel((x, y), (*[int(c * strength) for c in target], a))
        save(f"rival_{color}_{pose}", im)

clean_alps = race.copy()
# Remove the embedded branded billboard, restoring adjoining mountain pixels.
clean_alps.paste(race.crop((73,110,109,129)), (109,110))
save("alps", cut(clean_alps, (0, 88, 320, 128), {(0, 0, 247)}))
for stage, second in [(2,130),(3,190),(4,250),(5,310)]:
    source = Image.open(REF / f'stage-{second}.png').convert('RGBA')
    # A backdrop strip contains horizon scenery only, above the road horizon.
    save(f'background_{stage}', source.crop((0,88,320,144 if stage>=4 else 128)))
# Authentic roadside tree and billboard pixels present in the explosion frame.
save("tree", cut(crash, (48, 64, 90, 201)))
sign = Image.new('RGBA',(32,15))
draw = ImageDraw.Draw(sign)
draw.rectangle((0,0,31,13), fill=(247,247,247))
draw.rectangle((1,1,30,12), fill=(33,66,115))
for x in (4,13,22):
    draw.polygon([(x,3),(x+4,3),(x+7,7),(x+4,10),(x,10),(x+3,7)], fill=(247,214,0))
draw.rectangle((14,14,16,14), fill=(148,148,148))
save("sign", sign)
save("house", cut(crash, (92, 106, 123, 128)))

fire = cut(crash, (92, 105, 217, 181))
# Keep the high saturation flames; remove scenery around the explosion.
for y in range(fire.height):
    for x in range(fire.width):
        r, g, b, a = fire.getpixel((x, y))
        if not (r > 130 and (r > b * 1.5 or (g > 170 and b < 150))):
            fire.putpixel((x, y), (0, 0, 0, 0))
for i, size in enumerate([(38, 29), (70, 48), (112, 72), (125, 76), (91, 56), (56, 32)]):
    frame = fire.resize(size, Image.Resampling.NEAREST)
    if i & 1:
        frame = ImageOps.mirror(frame)
    save(f"fire_{i}", frame)
save("fallen", cut(crash, (200, 173, 249, 196)))
for i in range(4):
    frame = upright.rotate(i * 75 + 30, Image.Resampling.NEAREST, expand=True)
    save(f"tumble_{i}", frame)

hud = Image.new("RGBA", (320, 50))
for box in [(22, 14, 52, 26), (134, 14, 171, 26), (190, 14, 239, 26),
            (24, 32, 65, 40), (200, 32, 241, 40)]:
    hud.alpha_composite(cut(race, box), box[:2])
save("hud", hud)

gate = Image.new('RGBA', (248, 153))
gate.alpha_composite(cut(start, (38, 71, 286, 91)), (0, 0))
gate.alpha_composite(cut(start, (38, 91, 69, 139)), (0, 20))
gate.alpha_composite(cut(start, (255, 91, 286, 139)), (217, 20))
draw = ImageDraw.Draw(gate)
for x in (6, 22, 221, 237):
    draw.rectangle((x, 68, x+2, 152), fill=(181,181,181))
save('gate', gate)

# Compact 5x7 bitmaps, expanded to 8-pixel tile pitch by the assembly renderer.
patterns = {
 '0':'01110 10001 10011 10101 11001 10001 01110', '1':'00100 01100 00100 00100 00100 00100 01110',
 '2':'01110 10001 00001 00010 00100 01000 11111', '3':'11110 00001 00001 01110 00001 00001 11110',
 '4':'00010 00110 01010 10010 11111 00010 00010', '5':'11111 10000 10000 11110 00001 00001 11110',
 '6':'01110 10000 10000 11110 10001 10001 01110', '7':'11111 00001 00010 00100 01000 01000 01000',
 '8':'01110 10001 10001 01110 10001 10001 01110', '9':'01110 10001 10001 01111 00001 00001 01110',
 'A':'01110 10001 10001 11111 10001 10001 10001', 'B':'11110 10001 10001 11110 10001 10001 11110',
 'C':'01111 10000 10000 10000 10000 10000 01111', 'D':'11110 10001 10001 10001 10001 10001 11110',
 'E':'11111 10000 10000 11110 10000 10000 11111', 'F':'11111 10000 10000 11110 10000 10000 10000',
 'G':'01111 10000 10000 10111 10001 10001 01111', 'H':'10001 10001 10001 11111 10001 10001 10001',
 'I':'01110 00100 00100 00100 00100 00100 01110', 'J':'00111 00010 00010 00010 10010 10010 01100',
 'K':'10001 10010 10100 11000 10100 10010 10001', 'L':'10000 10000 10000 10000 10000 10000 11111',
 'M':'10001 11011 10101 10101 10001 10001 10001', 'N':'10001 11001 10101 10011 10001 10001 10001',
 'O':'01110 10001 10001 10001 10001 10001 01110', 'P':'11110 10001 10001 11110 10000 10000 10000',
 'Q':'01110 10001 10001 10001 10101 10010 01101', 'R':'11110 10001 10001 11110 10100 10010 10001',
 'S':'01111 10000 10000 01110 00001 00001 11110', 'T':'11111 00100 00100 00100 00100 00100 00100',
 'U':'10001 10001 10001 10001 10001 10001 01110', 'V':'10001 10001 10001 10001 10001 01010 00100',
 'W':'10001 10001 10001 10101 10101 10101 01010', 'X':'10001 10001 01010 00100 01010 10001 10001',
 'Y':'10001 10001 01010 00100 00100 00100 00100', 'Z':'11111 00001 00010 00100 01000 10000 11111',
 '.':'00000 00000 00000 00000 00000 00110 00110', ':':'00000 00110 00110 00000 00110 00110 00000',
 '-':'00000 00000 00000 11111 00000 00000 00000', '/':'00001 00010 00010 00100 01000 01000 10000',
 '!':'00100 00100 00100 00100 00100 00000 00100', '+':'00000 00100 00100 11111 00100 00100 00000',
}
font = bytearray()
for code in range(128):
    rows = patterns.get(chr(code), '00000 '*6 + '00000').split()
    font.extend(int(row, 2) << 1 for row in rows)
# Match the original 8-pixel scoreboard numerals wherever source pixels exist.
for source, digits in [(race, '1751330'), (crash, '1438220')]:
    for index, char in enumerate(digits):
        for y in range(7):
            bits = 0
            for x in range(8):
                r,g,b,a = source.getpixel((64 + index*8+x, 16+y))
                if r > 100 and 20 < g < 200 and b < 40:
                    bits |= 1 << (7-x)
            font[ord(char)*7+y] = bits
(OUT / 'font.bin').write_bytes(font)

names = [p.stem for p in sorted(OUT.glob('*.bin')) if p.stem != 'font']
include = ['.section .rdata', '.balign 4', 'pixel_font: .incbin "assets/generated/font.bin"']
for name in names:
    include += ['.balign 4', f'art_{name}: .incbin "assets/generated/{name}.bin"']
include += ['.balign 8', 'background_frames: .quad art_alps, art_background_2, art_background_3, art_background_4, art_background_5']
include += ['.balign 8', 'bike_frames:', '.quad ' + ','.join(f'art_bike_{i}' for i in range(7))]
include += ['rival_frames:', '.quad ' + ','.join(f'art_rival_{c}_{i}' for c in range(3) for i in range(7))]
include += ['fire_frames:', '.quad ' + ','.join(f'art_fire_{i}' for i in range(6))]
include += ['tumble_frames:', '.quad ' + ','.join(f'art_tumble_{i}' for i in range(4))]
(ROOT / 'src' / 'art.s').write_text('\n'.join(include)+'\n', encoding='utf-8')
print(f'Prepared {len(names)} pixel assets and embedded font.')
