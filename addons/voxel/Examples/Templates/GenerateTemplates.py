"""Creates texture templates at various resolutions
"""
import os

import numpy as np
import cv2

TEMPLATE_DIR = 'Textures'


def draw_template(res: int):
    dp = f'{TEMPLATE_DIR}/{res}'
    os.makedirs(dp, exist_ok=True)

    a = new_image(res)
    draw_corners(a, res)
    draw_numbers(a, res)
    exclude_zero(a, res)
    cv2.imwrite(f'{dp}/Overlay.png', a)

    a = new_image(res)
    draw_stripes(a, res)
    exclude_zero(a, res)
    cv2.imwrite(f'{dp}/Color.png', a)

    a = new_image(res)
    cv2.imwrite(f'{dp}/Emission.png', a)

    a = new_image(res)
    a[:, :] = (127, 127, 127, 255)
    cv2.imwrite(f'{dp}/Normal.png', a)

    a = new_image(res)
    a[:, :] = (0, 127, 255, 255)
    cv2.imwrite(f'{dp}/RSMA.png', a)


def new_image(res):
    return np.zeros((16 * res, 16 * res, 4), np.uint8)


def draw_corners(a, res):
    if res < 2:
        return

    a = a.reshape(16, res, 16, res, 4)

    m = res - 1
    n = res // 4
    p = n + 1
    q = res - p

    a[:, 0, :, :p] = 255
    a[:, :p, :, 0] = 255

    a[:, m, :, q:] = 255
    a[:, q:, :, m] = 255

    a[:, m, :, :p] = (0, 0, 0, 255)
    a[:, :p, :, m] = (0, 0, 0, 255)

    a[:, 0, :, q:] = (0, 0, 0, 255)
    a[:, q:, :, 0] = (0, 0, 0, 255)


def exclude_zero(a, res):
    if res < 4:
        a[:res, :res] = (0, 0, 255, 255)
        return

    a[:res, :res] = 0

    m = res - 1
    w = res // 8
    for y in range(res):
        for x in range(res):
            if abs(x - y) <= w:
                a[y][x] = (0, 0, 255, 255)
                a[y][m - x] = (0, 0, 255, 255)


def draw_stripes(a, res):
    a[:, :] = (0, 0, 0, 255)
    q = (res + 1) // 2
    for y in range(16 * res):
        for x in range(16 * res):
            if (x + y) // q & 1 == 0:
                a[y, x] = (0, 127, 127, 255)


def draw_numbers(a, res):
    if res < 24:
        return

    for i in range(1, 256):
        text = f'{i:03d}'
        font_face = cv2.FONT_HERSHEY_SIMPLEX
        font_size = 3.2 * res / 256
        line_width = 1 if res < 64 else 2
        (w, h), _ = cv2.getTextSize(text, font_face, font_size, line_width)
        x = (i % 16) * res + (res - w) // 2
        y = (i // 16) * res + (res + h) // 2
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx or dy:
                    cv2.putText(a, text, (x + dx, y + dy), font_face, font_size, (31, 0, 0, 255), line_width, cv2.LINE_AA)
        cv2.putText(a, text, (x, y), font_face, font_size, (255, 255, 255, 255), line_width, cv2.LINE_AA)


def main():
    os.makedirs(TEMPLATE_DIR, exist_ok=True)

    with open(f'{TEMPLATE_DIR}/.gdignore', 'wt') as f:
        pass

    for i in range(9):
        draw_template(1 << i)


if __name__ == '__main__':
    main()
