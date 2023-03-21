set PYTHON=python
set TOOLS=..\..\..\Tools
%PYTHON% %TOOLS%\vox_to_images.py 64 80 48 VoxExport/Slice.png VoxExport/Palette.png Texture/Voxel.png Texture/Model.png
%PYTHON% %TOOLS%\build_textures.py 8 16 256 Material Texture
pause
