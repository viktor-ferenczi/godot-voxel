set PYTHON=python
set TOOLS=..\..\..\Tools
%PYTHON% -u -OO %TOOLS%\vox_to_images.py Vox/Slice.png Vox/Palette.png Voxel.png Model.png 48 32 32
%PYTHON% -u -OO %TOOLS%\build_textures.py palette.json ../../Materials Palette.png Color.png Emission.png Normal.png RSMA.png 512
