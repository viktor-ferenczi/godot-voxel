""" This conversion is a workaround until the proper Vox resource loader is working again

How to use:
- Export the Vox to slices format, then rename the PNG file as *Slice.png
- Export the Vox to obj format, then rename the resulting PNG file as *Palette.png
- Run this script (see usage by running it with no parameters)

For example:

python VoxToBox.py 64 80 48 Slice.png Palette.png Voxel.png Model.png

This process can convert only a single model.
It cannot convert the PBR material properties.

Requires Python 3.9+, numpy and opencv2

"""
import sys
import numpy as np
import cv2


DEBUG = False
TS_FIRST_TRANSPARENT = 64


def main():
    if not len(sys.argv) != 7:
        print(f'Usage: {sys.argv[0]} WIDTH HEIGHT DEPTH Slice.png Palette.png Voxel.png Model.png')
        print(f'Example: {sys.argv[0]} 64 80 48 VoxExport/Slice.png VoxExport/Palette.png Texture/Voxel.png Texture/Model.png')
        sys.exit(1)

    width, height, depth, slices_path, palette_path, voxels_path, model_path = sys.argv[1:]

    width = int(width)
    height = int(height)
    depth = int(depth)
    assert width % 16 == 0
    assert height % 16 == 0
    assert depth % 16 == 0

    w, h, d = width // 16, height // 16, depth // 16
    cc = w * h * d

    slices: np.ndarray = cv2.imread(slices_path, cv2.IMREAD_UNCHANGED)
    assert slices is not None, f"Failed to load slices: {slices_path}"
    assert slices.shape == (height * depth, width, 4)

    palette: np.ndarray = cv2.imread(palette_path)
    assert palette is not None, f"Failed to load palette: {palette_path}"

    palette = palette[:, :, :3]
    assert palette.shape == (1, 256, 3)

    slices = slices.reshape((d, 16, h, 16, w, 16, 4))
    slices = np.moveaxis(slices, 3, 4)
    slices = np.moveaxis(slices, 1, 3)
    assert slices.shape == (d, h, w, 16, 16, 16, 4)

    if DEBUG:
        cv2.imshow("slices", slices.reshape((cc * 16, 256, 4)))
        cv2.waitKey()

    voxels: np.ndarray = np.zeros((d, h, w, 16, 16, 16), np.uint8)
    mapped = set()
    for voxel, color in enumerate(palette[0, :-1]):
        color = tuple(color)
        if color in mapped:
            continue
        mask: np.ndarray = np.sum(slices[:, :, :, :, :, :, :3] == color, 6) == 3
        if DEBUG:
            print(f'Mapped color {color} to {1 + voxel}')
        voxels[mask] = 1 + voxel
        mapped.add(color)

    # Force empty voxels
    mask: np.ndarray = slices[:, :, :, :, :, :, 3] == 0
    voxels[mask] = 0

    if DEBUG:
        cv2.imshow("voxels", normalize(voxels.reshape((cc * 16, 256, 1))))
        cv2.waitKey()

    cv2.imwrite(voxels_path, voxels.reshape((cc * 16, 256, 1)))

    model: np.ndarray = np.zeros((16, 16, 16, 3), np.uint8)
    free_layer = 0
    for x in range(d):
        for y in range(h):
            for z in range(w):
                cube = voxels[x, y, z]
                corner = cube[0, 0, 0]
                has_content = np.any(cube != 0)
                is_full = corner != 0 and np.all(cube == corner)
                has_opaque = np.any(cube < TS_FIRST_TRANSPARENT)
                has_transparent = has_content and np.any(cube < TS_FIRST_TRANSPARENT)
                has_emissive = False  # TODO

                if has_content and not is_full:
                    model[x, y, z, 0] = free_layer & 255
                    model[x, y, z, 1] = free_layer >> 8
                    free_layer += 1

                model[x, y, z, 2] = (
                    int(has_content) +
                    2 * int(is_full) +
                    4 * int(has_opaque) +
                    8 * int(has_transparent) +
                    16 * int(has_emissive)
                )

    model_img = model.reshape((256, 16, 3))[:, :, ::-1]

    if DEBUG:
        print("model =", model[:d, :h, :w])
        cv2.imshow("model", normalize(model_img))
        cv2.waitKey()

    cv2.imwrite(model_path, model_img)

    print(f"Size in cubes: {w}x{h}x{d}")


def normalize(a: np.ndarray):
    m = np.min(a)
    return (a - m) / max(1, np.max(a) - m)


if __name__ == '__main__':
    main()
