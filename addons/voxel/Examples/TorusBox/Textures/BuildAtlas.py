"""Compiles a palette from material component images

Color tuples are in RGBA order.
Flipped to BGRA right before calling cv2.imwrite.

On normals see:
http://wiki.polycount.com/wiki/Normal_map

"""
import glob
import os
import os.path
from typing import List, Tuple

import numpy as np
import cv2

COUNT = 256
RES = 128

MATERIALS_DIR = 'Materials'
OUTPUT_DIR = '.'

FILENAMES_COLOR = ['color.png', 'color.jpg']
FILENAMES_EMISSION = ['emission.png', 'emission.jpg']
FILENAMES_NORMAL = ['normal.png', 'normal.jpg']
FILENAMES_HEIGHT = ['height.png', 'height.jpg']
FILENAMES_ROUGHNESS = ['roughness.png', 'roughness.jpg']
FILENAMES_SPECULAR = ['specular.png', 'specular.jpg']
FILENAMES_METALLIC = ['metallic.png', 'metallic.jpg']
FILENAMES_AMBIENT_OCCLUSION = ['ao.png', 'ao.jpg']

Color = Tuple[int, int, int, int]

TRANSPARENT = (0, 0, 0, 0)
BLACK = (0, 0, 0, 255)
RED = (255, 0, 0, 255)
WHITE = (255, 255, 255, 255)
DEEP_DARK_BLUE = (0, 0, 31, 255)
ZERO_NORMAL_AND_HEIGHT = (128, 128, 255, 255)
DEFAULT_RSMA = (255, 128, 0, 255)

R = np.array([0], np.int32)
G = np.array([1], np.int32)
B = np.array([2], np.int32)
A = np.array([3], np.int32)
RG = np.array([0, 1], np.int32)
GB = np.array([1, 2], np.int32)
BR = np.array([2, 0], np.int32)
GR = np.array([1, 0], np.int32)
BG = np.array([2, 1], np.int32)
RB = np.array([0, 2], np.int32)
RGB = np.array([0, 1, 2], np.int32)
RGBA = np.array([0, 1, 2, 3], np.int32)

MAGICAVOXEL_DEFAULT_PALETTE = [
    (n & 255, (n >> 8) & 255, (n >> 16) & 255, 255) for n in (
        0x00000000, 0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, 0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff,
        0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, 0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff,
        0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, 0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc,
        0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, 0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc,
        0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, 0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99,
        0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, 0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699,
        0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, 0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66,
        0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, 0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666,
        0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, 0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066,
        0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, 0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933,
        0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, 0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033,
        0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, 0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00,
        0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, 0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300,
        0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, 0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044,
        0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, 0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000,
        0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, 0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111,
    )
]


def new_image(res: int, value: Color) -> np.ndarray:
    return np.full((COUNT, res, res, 4), value, np.uint8)


def draw_stripes(a: np.ndarray):
    res = a.shape[1]
    assert a.shape == (COUNT, res, res, 4), a.shape

    q = (res + 1) // 2
    for y in range(res):
        for x in range(res):
            if (x + y) // q & 1 == 0:
                a[:, y, x] = (127, 127, 0, 255)


def draw_numbers(a):
    res = a.shape[1]
    assert a.shape == (COUNT, res, res, 4), a.shape

    if res < 24:
        return

    for i in range(COUNT):
        text = f'{i:03d}'
        font_face = cv2.FONT_HERSHEY_SIMPLEX
        font_size = 3.2 * res / 256
        line_width = 1 if res < 64 else 2
        (w, h), _ = cv2.getTextSize(text, font_face, font_size, line_width)
        x = (res - w) // 2
        y = (res + h) // 2
        deltas = list(range(-line_width * 2, line_width * 3))
        for dy in deltas:
            for dx in deltas:
                if dx or dy:
                    cv2.putText(a[i], text, (x + dx, y + dy), font_face, font_size, DEEP_DARK_BLUE, line_width, cv2.LINE_AA)
        cv2.putText(a[i], text, (x, y), font_face, font_size, WHITE, line_width, cv2.LINE_AA)


def draw_noise():
    rng = np.random.RandomState(42)
    noise = rng.randint(0, 256, (1024, 1024), np.uint8)
    cv2.imwrite('Noise/white_noise.png', noise)


def draw_rgb444():
    p = np.mgrid[0:256:17, 0:256:17, 0:256:17]
    p = np.moveaxis(p, 0, 3)
    p = p.reshape((4, 4, 16, 16, 3))
    p = np.moveaxis(p, 0, 2)
    p = p.reshape((64, 64, 3))
    cv2.imwrite('RGB444.png', p)


def exclude_zero(a):
    res = a.shape[1]
    assert a.shape == (COUNT, res, res, 4), a.shape
    a[0] = TRANSPARENT


def load_palette_texture(i: int, a: np.ndarray, cout: np.ndarray, cin: np.ndarray, names: List[str], *, default=None, palette=None):
    res = a.shape[1]
    assert 0 < i < COUNT
    assert a.shape == (COUNT, res, res, 4), a.shape
    assert cin.dtype == np.int32, cin.dtype
    assert cout.dtype == np.int32, cout.dtype
    assert len(cin.shape) == 1, cin.shape
    assert len(cout.shape) == 1, cout.shape
    assert cin.shape == cout.shape, (cin.shape, cout.shape)

    channels = cin.size
    assert channels, channels

    dir_path = f'{MATERIALS_DIR}/{i:03d}'
    if not os.path.isdir(dir_path):
        globs = glob.glob(dir_path + '.*')
        if len(globs) == 1:
            dir_path = globs[0]
        elif len(globs) > 1:
            raise IOError("Ambiguous directory names for material %d: %r" % (i, globs))

    for name in names:
        path = f'{dir_path}/{name}'
        if os.path.exists(path):
            break
    else:
        if default is not None:
            a[i, :, :] = default
        if palette is not None:
            a[i, :, :] = palette[i]
        return

    print(f'{i:03} {name}')
    b = cv2.imread(path, cv2.IMREAD_GRAYSCALE if channels == 1 else cv2.IMREAD_UNCHANGED)

    # Must have channels
    if len(b.shape) == 2:
        b = b.reshape((res, res, -1))
    assert len(b.shape) == 3, b.shape

    # Resize to the target resolution
    if b.shape[:2] != (res, res):
        b = cv2.resize(b, (res, res), interpolation=cv2.INTER_CUBIC)

    # BGR => RGB
    if b.shape[2] >= 3:
        b[:, :, [0, 1, 2]] = b[:, :, [2, 1, 0]]

    # Add an opaque alpha channel if missing
    if channels == 4 and b.shape[2] == 3:
        alpha = np.full((res, res, 1), 255)
        b = np.concatenate([b, alpha], 2)

    # Store
    assert b.shape[2] >= channels, f'image has {b.shape[2]} channels, but at least {channels} are required'
    for ai, bi in zip(cout, cin):
        a[i, :, :, ai] = b[:, :, bi]


def save_texture(a: np.ndarray, name: str, ch: np.ndarray):
    res = a.shape[1]
    assert a.shape == (COUNT, res, res, 4), a.shape

    a = a.reshape((COUNT // 16, 16, res, res, 4))
    a = np.moveaxis(a, 1, 2)
    a = a.reshape((COUNT // 16 * res, 16 * res, 4))
    a = a[:, :, ch]

    if a.shape[2] >= 3:
        a[:, :, :3] = a[:, :, :3][:, :, ::-1]

    cv2.imwrite(f'{OUTPUT_DIR}/{name}.png', a)


def main():
    res = RES

    color = new_image(res, BLACK)
    emission = new_image(res, BLACK)
    normal = new_image(res, ZERO_NORMAL_AND_HEIGHT)
    rsma = new_image(res, DEFAULT_RSMA)

    draw_stripes(color)
    draw_numbers(color)
    exclude_zero(color)

    for i in range(1, COUNT):
        load_palette_texture(i, color, RGBA, RGBA, FILENAMES_COLOR)
        load_palette_texture(i, emission, RGB, RGB, FILENAMES_EMISSION, default=BLACK)
        load_palette_texture(i, normal, RG, RG, FILENAMES_NORMAL)
        load_palette_texture(i, normal, B, R, FILENAMES_HEIGHT)
        load_palette_texture(i, rsma, R, R, FILENAMES_ROUGHNESS)
        load_palette_texture(i, rsma, G, R, FILENAMES_SPECULAR)
        load_palette_texture(i, rsma, B, R, FILENAMES_METALLIC)
        load_palette_texture(i, rsma, A, R, FILENAMES_AMBIENT_OCCLUSION)

    save_texture(color, 'Color', RGBA)
    save_texture(emission, 'Emission', RGB)
    save_texture(normal, 'Normal', RGB)
    save_texture(rsma, 'RSMA', RGBA)

    #draw_noise()
    #draw_rgb444()


if __name__ == '__main__':
    main()
