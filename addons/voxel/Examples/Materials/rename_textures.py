import os

""" Material texture renamer tool

If you happen to download more materials from https://3dtextures.me
then this script will assist in renaming the image files to the names
expected by the build script.

Example source names from a downloaded ZIP file:

Material_2015.jpg
Wood_Wicker_010_ambientOcclusion.jpg
Wood_Wicker_010_basecolor.jpg
Wood_Wicker_010_height.png
Wood_Wicker_010_normal.jpg
Wood_Wicker_010_opacity.jpg
Wood_Wicker_010_roughness.jpg

"""


def rename(a, b):
    print(f'{a} => {b}')
    os.rename(a, b)


def main():
    for dirpath, dirnames, filenames in os.walk('.'):
        for fn in filenames:
            fn = fn.lower()
            for ext in ('jpg', 'png'):
                if not fn.endswith(f'.{ext}'):
                    continue
                elif fn.endswith(f'_ambientocclusion.{ext}') or fn.endswith(f'_occ.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/ao.{ext}')
                elif fn.endswith(f'_basecolor.{ext}') or fn.endswith(f'_color.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/color.{ext}')
                elif fn.endswith(f'_height.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/height.{ext}')
                elif fn.endswith(f'_disp.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/displacement.{ext}')
                elif fn.endswith(f'_normal.{ext}') or fn.endswith(f'_norm.{ext}') or fn.endswith(f'_nrm.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/normal.{ext}')
                elif fn.endswith(f'_opacity.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/opacity.{ext}')
                elif fn.endswith(f'_roughness.{ext}') or fn.endswith(f'_rough.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/roughness.{ext}')
                elif fn.endswith(f'_metallic.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/metallic.{ext}')
                elif fn.endswith(f'_spec.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/specular.{ext}')
                elif fn.endswith(f'_render.{ext}'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/preview.{ext}')
                elif fn.startswith('material_') or fn.startswith('wood_') or fn.startswith('stone_') or fn.startswith('metal_'):
                    rename(f'{dirpath}/{fn}', f'{dirpath}/preview.{ext}')


if __name__ == '__main__':
    main()
