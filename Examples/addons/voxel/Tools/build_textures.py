"""Compiles a palette and a texture atlas from materials

On normals see:
http://wiki.polycount.com/wiki/Normal_map

"""
import json
import os
import os.path
import sys
from typing import List, Tuple, Dict, Optional

import numpy as np
import cv2

DEBUG = True

Color = Tuple[int, int, int, int]

# Color values
TRANSPARENT = (0, 0, 0, 0)
BLACK = (0, 0, 0, 255)
RED = (255, 0, 0, 255)
WHITE = (255, 255, 255, 255)
DEEP_DARK_BLUE = (0, 0, 31, 255)
DEFAULT_NORMAL_AND_HEIGHT = (128, 128, 255, 255)
DEFAULT_RSMA = (255, 128, 0, 255)

# Material channel mapping
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

# Material filenames
MAT_COLOR = ['color.png', 'color.jpg']
MAT_EMISSION = ['emission.png', 'emission.jpg']
MAT_NORMAL = ['normal.png', 'normal.jpg']
MAT_HEIGHT = ['height.png', 'height.jpg']
MAT_ROUGHNESS = ['roughness.png', 'roughness.jpg']
MAT_SPECULAR = ['specular.png', 'specular.jpg']
MAT_METALLIC = ['metallic.png', 'metallic.jpg']
MAT_AMBIENT_OCCLUSION = ['ao.png', 'ao.jpg']

# Bit flags
IS_OPAQUE = 1
HAS_COLOR = 2
HAS_EMISSION = 4
HAS_NORMAL = 8
HAS_RSMA = 16


def new_texture(res: int, color: Color) -> np.ndarray:
    """ Creates a new texture filled with color
    """
    if color == TRANSPARENT:
        return np.zeros((res, res, 4), np.uint8)

    return np.full((res, res, 4), color, np.uint8)


def new_atlas(res: int, count: int, channels: np.ndarray):
    """ Creates a new texture atlas
    """
    cols = min(count * res, 4096) // res
    rows = (count + cols - 1) // cols
    return np.zeros((rows * res, cols * res, channels.size), np.uint8)


def draw_red_x(r: int) -> np.ndarray:
    x = np.zeros((r, r, 3), np.uint8)
    cv2.rectangle(x, (1, 1), (r - 2, r - 2), (255, 0, 0), 3)
    cv2.line(x, (0, 0), (r - 1, r - 1), (255, 0, 0), 3)
    cv2.line(x, (r - 1, 0), (0, r - 1), (255, 0, 0), 3)
    return x


def write_texture(path, a):
    """ Writes a texture to disk with the right color channel order
    """
    if a.shape[2] == 4:
        f = a[:, :, [2, 1, 0, 3]]
    else:
        f = a[:, :, ::-1]
    cv2.imwrite(path, f)


def load_channel(mat_dir: str, res: int, out: np.ndarray, cout: np.ndarray, cin: np.ndarray, filenames: List[str]) -> int:
    """ Loads the selected color channels from the input material
    into the selected output channels of an in-memory output array
    """
    assert out.shape == (res, res, 4), out.shape
    assert cin.dtype == np.int32, cin.dtype
    assert cout.dtype == np.int32, cout.dtype
    assert len(cin.shape) == 1, cin.shape
    assert len(cout.shape) == 1, cout.shape
    assert cin.shape == cout.shape, (cin.shape, cout.shape)

    channels = cin.size
    assert channels, channels

    for name in filenames:
        path = f'{mat_dir}/{name}'
        if os.path.exists(path):
            break
    else:
        # Not found in the material
        return 0

    mat = cv2.imread(path, cv2.IMREAD_GRAYSCALE if channels == 1 else cv2.IMREAD_UNCHANGED)

    # Must have channels
    if len(mat.shape) == 2:
        mat = mat.reshape((res, res, -1))
    assert len(mat.shape) == 3, mat.shape

    # BGR => RGB
    if mat.shape[2] >= 3:
        mat[:, :, [0, 1, 2]] = mat[:, :, [2, 1, 0]]

    # Resize to the target resolution
    if mat.shape[:2] != (res, res):
        mat = cv2.resize(mat, (res, res), interpolation=cv2.INTER_LANCZOS4)

    # Add an opaque alpha channel if there is none
    if channels == 4 and mat.shape[2] == 3:
        alpha = np.full((res, res, 1), 255)
        mat = np.concatenate([mat, alpha], 2)

    # Copy the selected input channels to the selected output channels
    assert mat.shape[2] >= channels, f'image has {mat.shape[2]} channels, but at least {channels} are required'
    for ai, bi in zip(cout, cin):
        out[:, :, ai] = mat[:, :, bi]

    # Found in the material
    return 1


class Material:
    """ Material

    Represents the PBR material for a single voxel face.

    Channels may be missing, in which case the shader will use
    its default value and don't have to read any texture.

    """

    def __init__(self, mat_dir: str, res: int):
        self.has_color = 0
        self.has_emission = 0
        self.has_normal = 0
        self.has_rsma = 0

        self.color = new_texture(res, BLACK)
        self.emission = new_texture(res, BLACK)
        self.normal = new_texture(res, DEFAULT_NORMAL_AND_HEIGHT)
        self.rsma = new_texture(res, DEFAULT_RSMA)

        self.has_color |= load_channel(mat_dir, res, self.color, RGBA, RGBA, MAT_COLOR)
        self.has_emission |= load_channel(mat_dir, res, self.emission, RGB, RGB, MAT_EMISSION)
        self.has_normal |= load_channel(mat_dir, res, self.normal, RG, RG, MAT_NORMAL)
        self.has_normal |= load_channel(mat_dir, res, self.normal, B, R, MAT_HEIGHT)
        self.has_rsma |= load_channel(mat_dir, res, self.rsma, R, R, MAT_ROUGHNESS)
        self.has_rsma |= load_channel(mat_dir, res, self.rsma, G, R, MAT_SPECULAR)
        self.has_rsma |= load_channel(mat_dir, res, self.rsma, B, R, MAT_METALLIC)
        self.has_rsma |= load_channel(mat_dir, res, self.rsma, A, R, MAT_AMBIENT_OCCLUSION)

        has_any = self.has_color | self.has_emission | self.has_normal | self.has_rsma
        if not has_any:
            raise IOError(f"Could not load any channels for material: {mat_dir}")

        self.is_opaque = self.has_color and np.all(self.color[:, :, 3] == 255)

        self.flags = (
            self.is_opaque * IS_OPAQUE |
            self.has_color * HAS_COLOR |
            self.has_emission * HAS_EMISSION |
            self.has_normal * HAS_NORMAL |
            self.has_rsma * HAS_RSMA)


class Palette:
    """ Material palette

    Contains materials for each of the 6 sides of the voxel for all voxel values in use.

    Size: 6x256
    Format: RGB8
    RG: Texture layer index
    B: Bit flags as described in Palette

    """

    def __init__(self, palette_json_path: str, materials_dir: str, palette_png_path: str, color_png_path: str, emission_png_path: str, normal_png_path: str, rsma_png_path: str, res: int):
        self.materials_dir = materials_dir
        self.palette_png_path = palette_png_path
        self.color_png_path = color_png_path
        self.emission_png_path = emission_png_path
        self.normal_png_path = normal_png_path
        self.rsma_png_path = rsma_png_path
        self.res = res

        assert os.path.isdir(materials_dir)

        with open(palette_json_path, 'rt') as f:
            self.palette_json = json.load(f)

        self.palette: np.ndarray = np.zeros((256, 6, 3), np.uint8)

        self.color_textures: List[np.ndarray] = []
        self.emission_textures: List[np.ndarray] = []
        self.normal_textures: List[np.ndarray] = []
        self.rsma_textures: List[np.ndarray] = []

        self.color_atlas: Optional[np.ndarray] = None
        self.emission_atlas: Optional[np.ndarray] = None
        self.normal_atlas: Optional[np.ndarray] = None
        self.rsma_atlas: Optional[np.ndarray] = None

        self.red_x = draw_red_x(res)

    def process(self):
        materials = self.palette_json["materials"]
        names, layers, flags = self.load_materials(materials)

        self.fill_palette(materials, layers, flags)
        self.verify_palette()

        write_texture(self.palette_png_path, self.palette)
        write_texture(self.color_png_path, self.color_atlas)
        write_texture(self.emission_png_path, self.emission_atlas)
        write_texture(self.normal_png_path, self.normal_atlas)
        write_texture(self.rsma_png_path, self.rsma_atlas)

        if DEBUG:
            print('Palette (used items only):')
            for i, row in enumerate(self.palette):
                if np.any(row != 0):
                    print(f'Voxel value {i}: ')
                    for f, face in enumerate(row):
                        mat_index = face[0]
                        name = names[mat_index]
                        flg = flags[name]
                        f_flg = ''.join([
                            'IS_OPAQUE ' if flg & IS_OPAQUE else '',
                            'HAS_COLOR ' if flg & HAS_COLOR else '',
                            'HAS_EMISSION ' if flg & HAS_EMISSION else '',
                            'HAS_NORMAL ' if flg & HAS_NORMAL else '',
                            'HAS_RSMA ' if flg & HAS_RSMA else '',
                        ]).rstrip()
                        print(f'  Face {f}: {face} {name} {f_flg}')
            print()

    def load_materials(self, materials: Dict[str, List[str]]) -> Tuple[List[str], Dict[str, int], Dict[str, int]]:
        res = self.res

        names = sorted(set().union(*list(materials.values())))
        count = len(names)

        self.color_atlas = new_atlas(res, count, RGBA)
        self.emission_atlas = new_atlas(res, count, RGB)
        self.normal_atlas = new_atlas(res, count, RGB)
        self.rsma_atlas = new_atlas(res, count, RGBA)

        cols = self.color_atlas.shape[1] // res
        rows = self.color_atlas.shape[0] // res
        print(f'Slices: {cols}x{rows}')

        if DEBUG:
            print('Materials:')

        layers = {}
        flags = {}
        for i, name in enumerate(names):

            col = i % cols
            row = i // cols

            x = col * res
            y = row * res

            mat = Material(os.path.join(self.materials_dir, name), res)

            if DEBUG:
                channels = ''.join([
                    'color ' if mat.has_color else '',
                    'emission ' if mat.has_emission else '',
                    'normal ' if mat.has_normal else '',
                    'rsma ' if mat.has_rsma else '',
                ]).rstrip()
                print(f'{i:3d}: {name} ({channels})')

            color = self.color_atlas[y:y + res, x:x + res]
            if mat.has_color:
                color[:] = mat.color
            else:
                color[:, :, :3] = self.red_x

            emission = self.emission_atlas[y:y + res, x:x + res]
            if mat.has_emission:
                emission[:] = mat.emission[:, :, :3]
            else:
                emission[:] = self.red_x

            normal = self.normal_atlas[y:y + res, x:x + res]
            if mat.has_normal:
                normal[:] = mat.normal[:, :, :3]
            else:
                normal[:] = self.red_x

            rsma = self.rsma_atlas[y:y + res, x:x + res]
            if mat.has_rsma:
                rsma[:] = mat.rsma
            else:
                rsma[:, :, :3] = self.red_x

            flags[name] = mat.flags
            layers[name] = i
            self.color_textures.append(color)
            self.emission_textures.append(emission)
            self.normal_textures.append(normal)
            self.rsma_textures.append(rsma)

        if DEBUG:
            print()

        return names, layers, flags

    def fill_palette(self, materials: Dict[str, List[str]], layers: Dict[str, int], flags: Dict[str, int]):
        for voxel, names in materials.items():

            if not voxel.isdigit():
                raise ValueError(f'Invalid voxel value: {voxel}')
            voxel = int(voxel)
            if voxel < 1 or voxel > 255:
                raise ValueError(f'Invalid voxel value: {voxel}')

            if len(names) == 1:
                names *= 6
            if len(names) != 6:
                raise ValueError(f'Invalid material names at voxel {voxel:03d}: {repr(names)}')

            for i, name in enumerate(names):
                layer = layers.get(name, 0)
                flag = flags.get(name, 0)
                self.palette[voxel, i] = [layer & 255, layer >> 8, flag]

    def verify_palette(self):
        opaque_counts = np.sum(self.palette[:, :, 2] & 1, axis=1, dtype=np.uint8)
        mixed_opaque_transparent = np.logical_and(opaque_counts > 0, opaque_counts < 6)
        if np.any(mixed_opaque_transparent):
            print('ERROR: Palette entries with mixed opaque and transparent sides:', repr(list(np.nonzero(mixed_opaque_transparent)[0])))
            sys.exit(1)


def main():
    if len(sys.argv) != 9:
        print(f'Usage: {sys.argv[0]} MATERIAL_DIR TEXTURE_DIR PALETTE_JSON RESOLUTION')
        print(f'Examples: {sys.argv[0]} palette.json ../../Materials Palette.png Color.png Emission.png Normal.png RSMA.png 512')
        sys.exit(1)

    args = sys.argv[1:9]
    args[-1] = int(args[-1])
    palette = Palette(*args)
    palette.process()


if __name__ == '__main__':
    main()
