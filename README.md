# Voxel

**Efficient voxel rendering addon for Godot 4.0.**

It uses fragment shaders instead of converting the voxels to a mesh.
This approach allows for good performance and opens up the possibility
of making runtime changes to voxels at a relatively low cost.

## How to use

See under `addons\voxel\Examples\TorusBox`

The configuration is quite picky to how the texture arrays are 
imported. If you get rendering errors in the Output tab, then
that's the most likely reason.

## Remarks

Shadows received by the voxel and the lighting are incorrect 
with the current official Godot 4.0 release.

Reason is detailed in [Proposal 1942](https://github.com/godotengine/godot-proposals/issues/1942)
and a solution has been proposed in [PR 65307](https://github.com/godotengine/godot/pull/65307).

At the time of writing this change has not been made it into the 
official Godot release. **Please vote on them. Thank you!**

In order to get proper lighting you need to rebuild Godot with the 
changes from the above PR included.

1. Fork the Godot repository (if you haven't yet)
2. Create a branch
3. Cherry-pick the changes from the above PR's branch
4. Build a release version of Godot locally

```sh
set PYTHONUNBUFFERED=1
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
scons -j 12 platform=windows target=editor >build.log 2>&1
```

Customize the `-j` parameter to match the number of threads your CPU can run in parallel.

If you have enough free RAM, then it is usually faster to build Godot on a ramdisk. 
You can create one using [ImDisk](https://sourceforge.net/projects/imdisk-toolkit/).

It also saves quite a few writes to your NVMe/SSD.

Don't forget to copy your Godot binary from the ramdisk to your normal disk,
because the ramdisk contents are lost on OS reboots.
