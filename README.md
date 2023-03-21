# Voxel

**Voxel rendering addon for Godot 4.0.**

Based on an efficient 2-level DDA algorithm, implemented 100% on the GPU as a fragment shader.

This approach allows for good performance and opens up the possibility of making runtime changes
to voxels at a relatively low cost.

Detailed documentation in mostly in the shader source files.

Scroll down on this page for screenshots on what's possible. 

## Example

Open the scene from: `addons\voxel\Examples\TorusBox`

![Example TorusBux scene](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Preview.png)

Check out the textures configured on the `TextureVoxelBox` node.

There are separate shaders for the opaque, transparent and shadow passes.
They are rendered by their own child nodes, the shaders are defined there.
GDScript is required only to verify the configuration and set up the child
nodes in a consistent way.

## Algorithm

The shader is based on a 2-level DDA algorithm, this is also known as raymarching.

From the perspective of the volume the voxels are rendered into is just the simplest
possible box mesh. It does not have anything else other than 8 vertices and 12 faces.
It does not need UV, nor normals. 

Front faces are culled, only the back faces are rendered. It allows for viewing the
voxel volume from inside, while still provide full view from the outside.

For each view ray the shader
* map the ray to the voxel box (model space)
* calculate front face intersection from the back one
* walks over the voxel cubes (1st level)
* skip any voxel cubes behind the view plane
* for each voxel cube with any non-empty voxels
  * skip any voxels behind the view plane
  * call the sampler to determine whether the voxel exists, opaque or transparent
  * accumulate transparent voxels along the ray
  * stop at the first opaque voxel along the ray
* call the sampler to fetch PBR properties (separate for opaque and transparent)

The opaque, transparent and shadow passes differ, because they do only the
processing required for the given pass. Transparent voxels are not rendered
to the shadow map, for example.

The DDA algorithm in the shader code is designed to be reusable. It is easy
to provide a custom sampler for your specific needs without touching the
raymarching algorithm. This way you can change the PBR material of your
voxels in any way you want and look up extra information based on the voxel
type or position to match your game design goals. What is considered to be
opaque voxel can also be customized.

## Remarks

### Vox import

There was a Vox resource loader, but it got broken by a late Godot beta.

### Texture array imports

The texture array import configuration is critical for the shader to accept
the textures. If you get rendering errors in the Output tab, then that's the
most likely reason.

### Transparency

Transparency is not tested with this current project, but worked well before.
I will include a test project for transparency later.

The shader implements color filtering with proper transmittance calculation.
It is taking the screen texture as the background, which poses some limitations.
Color filtering works as expected inside the same voxel volume, but 

### Same texture is used on all sides

The current code maps the same texture to all 6 sides of the voxels. It can be
a problem in case of some games, where the top and bottom sides may differ.
The shader does not pass the side information (xyz sign of the ray direction
in model space) to the sampler in the current code.

### Incorrect received shadows and lighting

Shadows received by the voxel and the lighting (normals) are incorrect with the
current official Godot 4.0 release.

* Reason is detailed in [Proposal 1942](https://github.com/godotengine/godot-proposals/issues/1942)
* A solution has been proposed in [PR 65307](https://github.com/godotengine/godot/pull/65307)

At the time of writing the fix has **not** been made it into an official Godot release.

**Please vote on the above PR and proposal. Thank you!**

In order to get proper lighting you need to rebuild Godot with the changes from the
above PR merged into the official code. At the time of writing the changes can merge
with both the Godot 4.0 code and the current master (4.1).

1. Fork the Godot repository (if you haven't yet)
2. Create a new branch and switch to it
3. Cherry-pick the changes from the above PR's branch
4. Build a release version of Godot locally

```sh
set PYTHONUNBUFFERED=1
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
scons -j 12 platform=windows target=editor >build.log 2>&1
```

Customize the `-j` parameter to match the number of threads your CPU can run in parallel.

If you have enough free RAM, then it is faster to build Godot on a ramdisk.
You can create one using [ImDisk](https://sourceforge.net/projects/imdisk-toolkit/).

(It also saves quite a few writes to your NVMe/SSD.)

Don't forget to copy your Godot binary from the ramdisk to your normal disk at the end,
ramdisk contents are lost on the next OS reboot.

## Plans

* Rename Model to something else, because it can be confused with Godot's Cubemap feature (which is unrelated)
* Resurrect the Vox resource loader
* Add support for different textures on each side of the voxel
* Clean up the Python texture atlas pre-processing code
* Clean up and add the automated placement of
  * Lights to make use of SDFGI
  * Occluders to reduce overdraw
  * Colliders to enable physics
* Add more examples (PRs are very welcome, I'm not an artist)

### Screenshots

Screenshots and videos what this plugin may be able to do later, once I can clean up and add
all the GDExtension based C code back to the project which I had to remove.

Voxel asserts used in the tests: [Tiny Voxel Dungeon](https://maxparata.itch.io/tinyvoxeldungeon) by [maxparata](https://maxparata.itch.io/)

#### Vox import

Godot (SDFGI, SSAO, Glow) vs. MagicaVoxel rendering: [Full resolution](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/GodotVsMagicaVoxel.full.png)
![Godot vs. MagicaVoxel](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/GodotVsMagicaVoxel.png)

#### Light placement

Automated placement of light in the cluster centroids of emissive voxels:
![Light Placement](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/LightPlacement.png)

Lighting test:
![Lighting](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/Lighting.png)

Staircase lights:
![Staircase Lights](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/StaircaseLights.png)

#### Occluders

I made no screenshots of occluder placement, but they work similarly to collider placement.

#### Colliders, physics

Collider placement

![Collision Boxes](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/CollisionBoxes.png)

![Collision Shapes](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/CollisionShapes.png)

Videos are on OneDrive, because they are big.

* [Bouncing balls over voxel room](https://1drv.ms/u/s!AqEgz8G_d8TSh94mj4Xh3eAsVwPa1w?e=OwGMnb)
* [Voxel-voxel collision physics](https://onedrive.live.com/?authkey=%21AKhfjwQROfvOdh8&id=D2C477BFC1CF20A1%21126766&cid=D2C477BFC1CF20A1&parId=root&parQt=sharedby&o=OneUp)

#### Transparent voxels

![Transparency Nature](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/TransparencyNature.png)

![Transparency Venice](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/TransparencyVenice.png)

It actually calculates color transmittance, so colorful glass behaves as expected. Unfortunately
there are no colorful shadows. They could be faked with projectors, which should be supported
(not tested it yet).

#### Rendering performance tests

60fps with 64 rooms (geForce RTX 3080Ti)
![Perf. test: 64 rooms](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/PerfRooms64.png)

With automated light placement included (no fps recorded, unfortunately, it was around 30-40):
![Perf. test: Lighting, 64 rooms](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/PerfLighting64.png)

#### Fun bugs

A bug resulted in a fancy memory garbage visualizer during shader development:

![Bug: Fancy Memory Garbage Visualizer](https://github.com/viktor-ferenczi/godot-voxel/raw/main/screenshots/BugFancyMemoryGarbage.png)
