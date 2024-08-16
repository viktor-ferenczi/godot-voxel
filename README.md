# Voxel

**Voxel rendering addon for Godot 4.3.**

Based on an efficient 2-level DDA algorithm, implemented 100% on the GPU as a fragment shader.

This approach allows for good performance and opens up the possibility of making runtime changes
to voxels at a relatively low cost.

Detailed documentation in mostly in the shader source files.

Scroll down on this page for screenshots on what's possible. 

## Example

Open the example scenes:
- `Examples\Park`
- `Examples\TorusBox`

![Example Park scene](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/Park.png)

![Example TorusBox scene](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/TorusBox.png)

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
Color filtering works as expected inside the same voxel volume, but falls back
to alpha channel by turning the transparency effectively grayscale. 

## Plans

* Resurrect the Vox resource loader
* Clean up and add the automated placement of
  * Lights to make use of SDFGI
  * Occluders to reduce overdraw
  * Colliders to enable physics
* Add a one bit per voxel texture to speed up skipping empty voxels.
* Add more examples (PRs are very welcome, I'm not an artist)

### Screenshots

Screenshots and videos what this plugin may be able to do later, once I can clean up and add
all the GDExtension based C code back to the project which I had to remove.

Voxel asserts used in the tests: [Tiny Voxel Dungeon](https://maxparata.itch.io/tinyvoxeldungeon) by [maxparata](https://maxparata.itch.io/)

#### Vox import

Godot (SDFGI, SSAO, Glow) vs. MagicaVoxel rendering: [Full resolution](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/GodotVsMagicaVoxel.full.png)
![Godot vs. MagicaVoxel](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/GodotVsMagicaVoxel.png)

#### Light placement

Automated placement of light in the cluster centroids of emissive voxels:
![Light Placement](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/LightPlacement.png)

Lighting test:
![Lighting](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/Lighting.png)

Staircase lights:
![Staircase Lights](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/StaircaseLights.png)

#### Occluders

I made no screenshots of occluder placement, but they work similarly to collider placement.

#### Colliders, physics

Collider placement

![Collision Boxes](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/CollisionBoxes.png)

![Collision Shapes](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/CollisionShapes.png)

Videos are on OneDrive, because they are big.

* [Bouncing balls over voxel room](https://1drv.ms/u/s!AqEgz8G_d8TSh94mj4Xh3eAsVwPa1w?e=OwGMnb)
* [Voxel-voxel collision physics](https://onedrive.live.com/?authkey=%21AKhfjwQROfvOdh8&id=D2C477BFC1CF20A1%21126766&cid=D2C477BFC1CF20A1&parId=root&parQt=sharedby&o=OneUp)

#### Transparent voxels

![Transparency Nature](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/TransparencyNature.png)

![Transparency Venice](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/TransparencyVenice.png)

It actually calculates color transmittance, so colorful glass behaves as expected. Unfortunately
there are no colorful shadows. They could be faked with projectors, which should be supported
(not tested it yet).

#### Rendering performance tests

60fps with 64 rooms (geForce RTX 3080Ti)
![Perf. test: 64 rooms](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/PerfRooms64.png)

With automated light placement included (no fps recorded, unfortunately, it was around 30-40):
![Perf. test: Lighting, 64 rooms](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/PerfLighting64.png)

#### Fun bugs

A bug resulted in a fancy memory garbage visualizer during shader development:

![Bug: Fancy Memory Garbage Visualizer](https://github.com/viktor-ferenczi/godot-voxel/raw/main/Docs/Screenshots/BugFancyMemoryGarbage.png)
