// Palette flags
const uint IS_OPAQUE = 1u;
const uint HAS_COLOR = 2u;
const uint HAS_EMISSION = 4u;
const uint HAS_NORMAL = 8u;
const uint HAS_RSMA = 16u;


/* Scaling factor for the voxel UV coordinates to control texture repetition

1.0: The texture covers 16x16 voxel faces (the entire voxel cube)
4:0: The texture covers 4x4 voxel faces
16.0: The texture covers 1x1 voxel face (single voxel cube)

Anything in-between will repeat the texture more than once over the voxel cube.

Leave it on the default 16.0 for "Minecraft like" games with large (1m^3)
voxels where the same block type should look the same everywhere.

Set it to a lower value between 1.0 and 8.0 for games with smaller voxels,
where the voxel textures are expected to have a bit of variance even if they
are of the same type (stone, rusty metal, tiled floor).

*/
uniform float uv_scale = 16.0;


/* Model size in voxel cubes

Each voxel cube contains 16x16x16 voxels.

*/
uniform ivec3 model_size;


/* Voxel cube information for the 1st level DDA

Format: RGB8
Size: 16 x 256

Each pixel in the cube map corresponds to a 16x16x16
voxel cube. Each voxel cube contains 16x16x16 voxels,
therefore the maximum voxel resolution is 256x256x256.

Two levels of DDA is used as an optimization to skip
empty voxel cubes entirely. It reduces overdraw and
the number of scene objects required.

The cube map tells whether a cube is empty or not.
If it has any content, then it also contains the
index of the voxel texture layer to render.

RG: Voxel texture layer index, unless the cube is empty or full

B: Content flags
Bit 0 has_content: 1 if the cube has any opaque or transparent voxels
Bit 1 is_full: 1 if the cube is full of the same voxel, which goes into R
Bit 2 has_opaque: 1 if the cube has any opaque voxels
Bit 3 has_transparent: 1 if the cube has any transparent voxels
Bit 4 has_emissive: 1 if the cube has any emissive voxels

These flags are used to optimize the rendering.

If the voxels are changed at runtime, then the cube map has to be updated
to reflect the modified contents of the affected voxel cubes.

*/
uniform sampler2D model_texture;


/* Voxel data as Texture2DArray for the 2nd level DDA

Format: R8
Size: 256 x 16 x CUBE_COUNT

There is only one byte per voxel to save on GPU memory.

A voxel is empty if its value is zero, the first palette
and material items (with an index of zero) are unused.

Use voxel values between 1..255 to identify the type of
the voxel, then look up any additional information
required, but only as much as needed.

GPU memory access is not cheap, caches are small and
very busy. Often it is better to run some extra
instructions to save on memory access. Consider
packing your data as much as possible.

The granularity of texture array updates is one voxel cube,
which is one layer in this texture (4096 bytes). It allows
for realtime voxel manipulation with minimal copying
overhead from CPU to GPU memory.

*/
uniform sampler2DArray voxel_textures;


/* Material palette

Format: RGB8
Size: 6 x 256

Each row corresponds to a voxel value. The first row is unused,
since the zero value represents the empty voxel.

Each row contains 6 pixels, one for each side of the voxel.

RG: Texture layer index
B: Bit flags:
Bit 0: 1 if opaque, 0 if transparent
Bit 1: 1 if has color texture, 0 if transparent
Bit 2: 1 if has emission
Bit 3: 1 if has normal map
Bit 4: 1 if has RSMA

*/
uniform sampler2D palette_texture;


/* Voxel face base color and transmittance textures

Format: RGBA8
Size: 1..256 layers of any size

Each layer provides base color or transmittance texture for each of the
256 possible voxel values. Voxels with a zero value are always empty,
therefore layer zero is not used.

In case of opaque voxels this texture is interpreted as base color and the
alpha channel is ignored.

In case of transparent voxels the RGB component of this texture interpreted
as color transmittance (proportion of light to pass through) and the alpha
as density. Internal surfaces between voxels with the same transmittance
are hidden, so they appear as the same piece of glass.

*/
uniform sampler2DArray color_textures: source_color;


/* Voxel face emission

Format: RGB8
Size: 1..256 layers of any size

Light emitted from the opaque voxel surface or from inside transparent
voxel interiors. The emissive color adds up from the subsequent transparent
voxels behind each other along the view ray.

Currently Godot's SDFGI does not use PBR emission directly for illumination,
but it still visible if the glow effect is enabled in the environment's
render settings.

Workaround: Emissive voxels can be clustered from voxel data, then
omni light sources placed in the cluster centroids representing the total
light emission and average size of the cluster. It works pretty well if
tuned properly and also allows to focus the light sources to the volume
visible/important to the player.

The first layer with index zero is ignored, that's the empty voxel.

*/
uniform sampler2DArray emission_textures: source_color;


/* Voxel face normal map

Format: RGB8
Size: 1..256 layers of any size

RG: Normal map X and Y values
B: Normal map depth

Neutral value: (0.5, 0.5, 1.0)

Applied only to the first visible transparent voxel along the view ray.

The first layer with index zero is ignored, that's the empty voxel.

*/
uniform sampler2DArray normal_textures: hint_normal;


/* Voxel face RSMA

Format: RGBA8
Size: 1..256 layers of any size

PBR roughness, specular, metallic and ambient occlusion.
Applied only to the first visible voxel along the view ray.

The first layer with index zero is ignored, that's the empty voxel.

*/
uniform sampler2DArray rsma_textures;


/* Returns information on a voxel cube (1st level DDA)

Called first for each voxel cube by all the shaders.

Returns true if the cube is present (used), false is not present (empty).

pos: Voxel cube position, each coordinate is in [0..15]
=>
layer: Layer to use to retrieve the voxels
has_opaque: Set to true if the cube contains any opaque voxels

*/
bool get_cube(ivec3 pos, out uint layer, out bool has_opaque) {
	ivec2 tpos = ivec2(pos.x | (pos.y << 4), pos.z);
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
	tpos = ivec3(vpos.x | (vpos.y << 4), vpos.z, int(layer));
	voxel = uint(texelFetch(voxel_textures, tpos, 0).r * 255.0);

	// It is intentional to not set color here. The texture lookup will require
	// the uv, so it will happen later in the *_material calls.

	if (voxel == 0u) {
		opaque = false;
		return false;
	}

	opaque = (uint(texelFetch(palette_texture, ivec2(0, int(voxel)), 0).b * 255.0) & IS_OPAQUE) != 0u;
	return true;
}


// PBR material lookups shared by both the opaque and transparent passes
void pbr_lookup(uint voxel, uint face, vec2 uv, out vec4 color, out vec3 emission, out vec3 normal_map, out vec4 rsma) {
	uvec3 palette = uvec3(texelFetch(palette_texture, ivec2(int(face), int(voxel)), 0).rgb * 255.0);

	uint flags = palette.b;
	uint layer_index = palette.r | (palette.g << 8u);

	color = (flags & HAS_COLOR) != 0u ? texture(color_textures, vec3(uv, float(layer_index))) : vec4(0.0);
	emission = (flags & HAS_EMISSION) != 0u ? texture(emission_textures, vec3(uv, float(layer_index))).rgb : vec3(0.0);
	normal_map = (flags & HAS_NORMAL) != 0u ? texture(normal_textures, vec3(uv, float(layer_index))).xyz : vec3(0.5, 0.5, 1.0);
	rsma = (flags & HAS_RSMA) != 0u ? texture(rsma_textures, vec3(uv, float(layer_index))) : vec4(1.0, 0.5, 0.0, 1.0);
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
	pbr_lookup(voxel, face, uv * uv_scale, color, emission, normal_map, rsma);
	albedo = color.rgb;
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
	pbr_lookup(voxel, face, uv * uv_scale, color, emission, normal_map, rsma);
	transmittance = 1.0 - color.rgb * (1.0 - color.a);  // FIXME: Preprocess this
}
