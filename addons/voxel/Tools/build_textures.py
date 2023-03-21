"""Compiles a palette from material component images

Color tuples are in RGBA order.
Flipped to BGRA right before calling cv2.imwrite.

On normals see:
http://wiki.polycount.com/wiki/Normal_map

"""
import glob
import os
import os.path
import sys
from typing import List, Tuple

import numpy as np
import cv2

if len(sys.argv) != 6:
    print(f'Usage: {sys.argv[0]} ROWS COLS RESOLUTION MATERIAL_DIR TEXTURE_DIR')
    print(f'Examples: {sys.argv[0]} 8 16 256 Material Texture')
    sys.exit(1)

ROWS = int(sys.argv[1])
COLS = int(sys.argv[2])
COUNT = ROWS * COLS
RES = int(sys.argv[3])
MATERIALS_DIR = sys.argv[4]
OUTPUT_DIR = sys.argv[5]

assert 2 <= COUNT <= 256
assert 2 <= RES <= 1024

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


def new_image(value: Color) -> np.ndarray:
    return np.full((COUNT, RES, RES, 4), value, np.uint8)


def draw_stripes(a: np.ndarray):
    RES = a.shape[1]
    assert a.shape == (COUNT, RES, RES, 4), a.shape

    q = (RES + 1) // 2
    for y in range(RES):
        for x in range(RES):
            if (x + y) // q & 1 == 0:
                a[:, y, x] = (127, 127, 0, 255)


def draw_numbers(a):
    RES = a.shape[1]
    assert a.shape == (COUNT, RES, RES, 4), a.shape

    if RES < 24:
        return

    for i in range(COUNT):
        text = f'{i:03d}'
        font_face = cv2.FONT_HERSHEY_SIMPLEX
        font_size = 3.2 * RES / 256
        line_width = 1 if RES < 64 else 2
        (w, h), _ = cv2.getTextSize(text, font_face, font_size, line_width)
        x = (RES - w) // 2
        y = (RES + h) // 2
        deltas = list(range(-line_width * 2, line_width * 3))
        for dy in deltas:
            for dx in deltas:
                if dx or dy:
                    cv2.putText(a[i], text, (x + dx, y + dy), font_face, font_size, DEEP_DARK_BLUE, line_width, cv2.LINE_AA)
        cv2.putText(a[i], text, (x, y), font_face, font_size, WHITE, line_width, cv2.LINE_AA)


def exclude_zero(a):
    RES = a.shape[1]
    assert a.shape == (COUNT, RES, RES, 4), a.shape
    a[0] = TRANSPARENT


def load_material(i: int, a: np.ndarray, cout: np.ndarray, cin: np.ndarray, names: List[str], *, default=None, palette=None):
    RES = a.shape[1]
    assert 0 < i < COUNT
    assert a.shape == (COUNT, RES, RES, 4), a.shape
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
    mat = cv2.imread(path, cv2.IMREAD_GRAYSCALE if channels == 1 else cv2.IMREAD_UNCHANGED)

    # Must have channels
    if len(mat.shape) == 2:
        mat = mat.reshape((RES, RES, -1))
    assert len(mat.shape) == 3, mat.shape

    # Resize to the target resolution
    if mat.shape[:2] != (RES, RES):
        mat = cv2.resize(mat, (RES, RES), interpolation=cv2.INTER_CUBIC)

    # BGR => RGB
    if mat.shape[2] >= 3:
        mat[:, :, [0, 1, 2]] = mat[:, :, [2, 1, 0]]

    # Add an opaque alpha channel if missing
    if channels == 4 and mat.shape[2] == 3:
        alpha = np.full((RES, RES, 1), 255)
        mat = np.concatenate([mat, alpha], 2)

    # Store
    assert mat.shape[2] >= channels, f'image has {mat.shape[2]} channels, but at least {channels} are required'
    for ai, bi in zip(cout, cin):
        a[i, :, :, ai] = mat[:, :, bi]


def save_texture(a: np.ndarray, name: str, ch: np.ndarray):
    assert a.shape == (COUNT, RES, RES, 4), a.shape

    a = a.reshape((ROWS, COLS, RES, RES, 4))
    a = np.moveaxis(a, 1, 2)
    a = a.reshape((ROWS * RES, COLS * RES, 4))
    a = a[:, :, ch]

    if a.shape[2] >= 3:
        # RGB => BGR
        a[:, :, :3] = a[:, :, :3][:, :, ::-1]

    cv2.imwrite(f'{OUTPUT_DIR}/{name}.png', a)


def main():
    assert os.path.isdir(MATERIALS_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    color = new_image(BLACK)
    emission = new_image(BLACK)
    normal = new_image(ZERO_NORMAL_AND_HEIGHT)
    rsma = new_image(DEFAULT_RSMA)

    draw_stripes(color)
    draw_numbers(color)
    exclude_zero(color)

    for i in range(1, COUNT):
        load_material(i, color, RGBA, RGBA, FILENAMES_COLOR)
        load_material(i, emission, RGB, RGB, FILENAMES_EMISSION, default=BLACK)
        load_material(i, normal, RG, RG, FILENAMES_NORMAL)
        load_material(i, normal, B, R, FILENAMES_HEIGHT)
        load_material(i, rsma, R, R, FILENAMES_ROUGHNESS)
        load_material(i, rsma, G, R, FILENAMES_SPECULAR)
        load_material(i, rsma, B, R, FILENAMES_METALLIC)
        load_material(i, rsma, A, R, FILENAMES_AMBIENT_OCCLUSION)

    save_texture(color, 'Color', RGBA)
    save_texture(emission, 'Emission', RGB)
    save_texture(normal, 'Normal', RGB)
    save_texture(rsma, 'RSMA', RGBA)


if __name__ == '__main__':
    main()
