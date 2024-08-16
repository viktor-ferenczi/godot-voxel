// Model size in 16x16x16 voxel cubes
uniform ivec3 model_size;


/* Model information for the 1st level DDA

Format: RGB8
Size: 256 x 16

Each pixel corresponds to a 16x16x16 voxel cube. 
Each voxel cube contains 16x16x16 voxels,
therefore the maximum voxel resolution is 256x256x256.

Two levels of DDA is used as an optimization to skip
empty voxel cubes entirely. It reduces overdraw and
the number of scene objects required.

The granularity of texture array updates is one layer
of voxels (16*16 = 256 bytes). It allows for realtime
voxel manipulation with minimal copying overhead from
CPU to GPU memory.

*/
uniform sampler2D model_texture;


/* Voxel data as Texture2DArray for the 2nd level DDA
Format: R8
Size: 16 x 256 x CUBE_COUNT

There is only one byte per voxel to save on GPU memory.

A voxel is empty if its value is zero, the first palette
and material items (with an index of zero) are unused.

Use voxel values between 1..255 to identify the type of
the voxel and look up additional information only if
required and as much as needed.

GPU memory access is not cheap, caches are small and
very busy. Often it is better to run some extra
instructions to save on memory access. Consider
packing your data as much as possible.

*/
uniform sampler2DArray voxel_textures;


/* Palette defining base color and opacity
Format: RGBA8
Size: 256 x 1

A voxel is opaque if its alpha in the palette is above 0.999,
otherwise the voxel is transparent.

The palette is kept as a separate texture, because it has to
go through colorspace conversion, while the material properties
don't. The palette and the materials define the FBR properties
returned to Godot to process the lighting.

*/
uniform sampler2D palette: source_color;


/* Material properties

Format: RGBA (no colorspace conversion)
Size: 5 x 256

Pixel columns:
0 tflg: x: material type [0..5], yzw: content flags to enable the material fields
1 rsma: rough, spec, metal, alpha
2 tial: trans, ior, att, ldr
3 femd: flux [1..5], emit, media [0..3], d
4 gs: g, sp [0..3]

Material types:
0 diffuse (roughness)
1 metal (rough, ior, spec, metal)
2 glass (rough, ior, trans, d)
3 emissive (emit, flux, ldr)
4 blend (rough, ior, spec, metal, trans, d, media)
5 media (media)

Media types:
0 absorb
1 scatter
2 emissive
3 subsurface scattering

*/
uniform sampler2D materials;


/* Returns information on a voxel cube (1st level DDA)

Called first for each voxel cube by all the shaders.

Returns true if the cube is present (used), false is not present (empty).

pos: Voxel cube position
=>
layer: Layer to use to retrieve the voxels
has_opaque: Set to true if the cube contains any opaque voxels

*/
bool get_cube(ivec3 pos, out uint layer, out bool has_opaque) {
	ivec2 tpos = ivec2(pos.x, pos.y | (pos.z << 4));
	uvec4 cube = uvec4(texelFetch(model_texture, tpos, 0) * 255.0);
	layer = cube.r | (cube.g << 8u);
	has_opaque = (cube.b & 4u) != 0u;
	return (cube.b & 1u) != 0u;
}


/* Determines whether a voxel is present (2nd level DDA)

Called first for each voxel by all the shaders.

Returns true if the voxel is present (used), false is not present (empty).
If the voxel is present, then optionally fills the voxel and color for use
by the opaque and transparent functions later. These two values are
not used by the shadow shader and should be optimized out in that case.

vpos: Voxel position inside the cube, each coordinate is in [0..15]
layer: Layer index into the voxels array, corresponds to the voxel cube rendered
=>
tpos: Texture array coordinates to pass to the other functions (optional)
voxel: Voxel information to pass to the other functions (optional)
color: Voxel RGBA color to pass to the other functions (optional)
opaque: Set to true if the voxel is opaque, false if the voxel is transparent

Make sure to use texelFetch to retrieve voxel information without filtering.
*/
bool get_voxel(ivec3 vpos, uint layer, out ivec3 tpos, out uint voxel, out vec4 color, out bool opaque) {
	tpos = ivec3(vpos.x, vpos.y | (vpos.z << 4), int(layer));
	voxel = uint(texelFetch(voxel_textures, tpos, 0).r * 255.0);
	color = texelFetch(palette, ivec2(int(voxel), 0), 0);
	opaque = color.a > 0.999;
	return voxel != 0u;
}


/* Determines the PBR surface material properties of opaque voxels (2nd level DDA)

Called only for the opaque voxels by the opaque shader.

tpos: Texture coordinates as returned by the get_voxel function
voxel: Voxel information as returned by the get_voxel function
color: Voxel color as returned by the get_voxel function
face: Voxel face hit by the ray [0..5], by face normal: -X +X -Y +Y -Z +Z
uv: Texture UV, [0..1] covers each quad face of the voxel cube (16x16 voxels)
=>
albedo: Surface color
emission: Color of emitted light, all zero for no emission
normal_map: Normal map xy values, z is the normal map depth, default is vec3(0.5, 0.5, 1.0)
rsma: Roughness, specular, metallic and ambient occlusion

Called only once per ray for the first opaque voxel hit by the ray.
*/
void get_opaque_material(ivec3 tpos, uint voxel, vec4 color, uint face, vec2 uv, out vec3 albedo, out vec3 emission, out vec3 normal_map, out vec4 rsma) {
	albedo = color.rgb;

	// Emissive materials are always rendered as transparent
	emission = vec3(0.0);

	normal_map = vec3(0.5, 0.5, 1.0);
	rsma = vec4(texelFetch(materials, ivec2(1, int(voxel)), 0).rgb, 1.0);
}


/* Determines the PBR surface material properties of transparent voxels (2nd level DDA)

Called only for the transparent voxels by the transparent shader.

tpos: Texture coordinates as returned by the get_voxel function
voxel: Voxel information as returned by the get_voxel function
color: Voxel color as returned by the get_voxel function
first: True if this is the first transparent voxel encountered along the ray
face: Voxel face hit by the ray [0..5], by face normal: -X +X -Y +Y -Z +Z
uv: Texture UV, [0..1] covers each quad face of the voxel cube (16x16 voxels)
=>
transmittance: Proportion of light to pass through
emission: Emissive color (adds up from voxels behind each other)
normal_map: Normal map xy values, z is the normal map depth (first voxel only)
rsma: Roughness, specular, metallic and ambient occlusion (first voxel only)

Called for each transparent voxel along the ray until it hits an opaque one or
exits the voxel cube. Transmittance is used only once for subsequent transparent
voxels with the same value. Surface normal_map and rsma are used only on the
first surface hit, no need to return those if first is false.
*/
void get_transparent_material(ivec3 tpos, uint voxel, vec4 color, uint face, vec2 uv, out vec3 transmittance, out vec3 emission, out vec3 normal_map, out vec4 rsma) {
	transmittance = 1.0 - color.rgb * (1.0 - color.a);

	vec4 femd = texelFetch(materials, ivec2(3, int(voxel)), 0);
	emission = femd.g > 0.001 ? color.rgb * (pow(2.0, femd.r * 5.0) * femd.g) * 32.0 : vec3(0.0);

	normal_map = vec3(0.5, 0.5, 1.0);
	rsma = vec4(texelFetch(materials, ivec2(1, int(voxel)), 0).rgb, 1.0);
}
