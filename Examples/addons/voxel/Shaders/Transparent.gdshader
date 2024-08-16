shader_type spatial;
render_mode skip_vertex_transform;
render_mode depth_draw_always;
render_mode cull_front;

#include "res://addons/voxel/Shaders/DDA.gdshaderinc"
#include "res://addons/voxel/Shaders/Config.gdshaderinc"

#if USE_TEXTURED_SAMPLER
#include "res://addons/voxel/Shaders/TexturedSampler.gdshaderinc"
#endif

#if USE_VOX_SAMPLER
#include "res://addons/voxel/Shaders/VoxSampler.gdshaderinc"
#endif

varying flat mat4 _MODELVIEW_MATRIX;
varying flat mat3 NORMALS;
varying flat vec3 MODEL_SIZE_REC;
varying smooth vec3 BACK;
varying smooth vec3 RAY;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture; // filter_linear_mipmaps

void vertex() {
	_MODELVIEW_MATRIX = MODELVIEW_MATRIX;

	// Surface normals in view space
	NORMALS[0] = normalize(MODELVIEW_MATRIX[0].xyz);
	NORMALS[1] = normalize(MODELVIEW_MATRIX[1].xyz);
	NORMALS[2] = normalize(MODELVIEW_MATRIX[2].xyz);

	// Precalculate reciprocal
	MODEL_SIZE_REC = 1.0 / vec3(model_size);

	// Voxel coordinates are encoded as interpolated vertex coordinates
	BACK = VERTEX;

	// Camera to vertex vector in model space
	RAY = safe_vector(VERTEX - (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz);

	// Original vertex transformation, but no need to transform the normal
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ray entering the voxel model
	vec3 ray = RAY;
	vec3 ray_rec = 1.0 / ray;
	vec3 front = to_front_face(BACK, ray, ray_rec);

	// 3D line drawing along 16x16x16 voxel cubes inside the whole voxel model
	DDA ddc;
	dda_init(ddc, model_size, front, ray, ray_rec);

	vec3 totalEmission = vec3(0.0);
	vec3 totalTrans = vec3(1.0);
	vec3 paint = vec3(0.0);
	bool first = true;
	bool inside = false;
	uint prevVoxel = 0u;
	bool stop = false;
	bool no_more_cubes = false;

	for(int csteps=0; csteps < 49; csteps++) {
		uint layer;
		bool has_opaque;

		// Consider only cubes with any opaque voxels
		if (get_cube(ddc.position, layer, has_opaque)) {

			// 3D line drawing along individual voxels inside the 16x16x16 voxel cube
			DDA ddv;
			vec3 origin;
			dda_init_inner(ddv, ddc, model_size, MODEL_SIZE_REC, ray, ray_rec, origin);

			float depth;
			no_more_cubes = dda_step(ddc);
			vec3 exit = dda_voxel_face_hit(ddc, MODEL_SIZE_REC);
			vec3 exit_vertex = calc_vertex(exit, PROJECTION_MATRIX, _MODELVIEW_MATRIX, depth);

			if(exit_vertex.z < 0.0) {
				for(int vsteps=0; vsteps < 49; vsteps++) {
					ivec3 tpos;
					uint voxel;
					vec4 color;
					bool opaque;

					// Consider both opaque and transparent voxels, but skip empty ones
					if (get_voxel(ddv.position, layer, tpos, voxel, color, opaque)) {

						// Ray intersection with the voxel's face (plane) in model coordinates
						vec3 hit = origin + dda_voxel_face_hit(ddv, vec3(1.0 / 16.0)) * MODEL_SIZE_REC;

						// Depth for intersection and lighting
						vec3 light_vertex = calc_vertex(hit, PROJECTION_MATRIX, _MODELVIEW_MATRIX, depth);

						// Consider only voxels in front of the screen
						if (light_vertex.z < 0.0) {

							// Encountering an opaque voxel stops the ray, since
							// it has already been rendered on the SCREEN_TEXTURE
							// by the opaque shader
							if (opaque) {
								stop = true;
								break;
							}

							inside = true;

							// UV for texturing
							uint face;
							vec2 uv = dda_voxel_face_uv(ddv, model_size, hit, face);

							// Material
							vec3 transmittance;
							vec3 emission;
							vec3 normal_map;
							vec4 rsma;
							get_transparent_material(tpos, voxel, color, face, uv, transmittance, emission, normal_map, rsma);

							// Accumulate emission on each voxel
							totalEmission += totalTrans * emission;

							// Accumulate transmittance only when it changes to show domain walls
							if (voxel != prevVoxel) {
								totalTrans *= transmittance;
								if (max(totalTrans.r, max(totalTrans.g, totalTrans.b)) < 0.01) {
									stop = true;
									break;
								}
								prevVoxel = voxel;
							}

							// Keep surface properties only for the first voxel encountered
							if (first) {
								first = false;

								// The first valid depth will be used for intersection
								DEPTH = depth;
								LIGHT_VERTEX = light_vertex;

								// Surface normals
								dda_voxel_face_normals(ddv, NORMALS, NORMAL, TANGENT, BINORMAL);

								// Material
								NORMAL_MAP = vec3(normal_map.xy, 0.0);
								NORMAL_MAP_DEPTH = normal_map.z;
								ROUGHNESS = rsma.r;
								SPECULAR = rsma.g;
								METALLIC = rsma.b;
								AO = rsma.a;

								// Paint color
								paint = color.rgb;
							}
						}
					} else {
						// Empty voxel
						if (inside) {
							inside = false;
							prevVoxel = 0u;
						}
					}

					if (dda_step(ddv)) {
						break;
					}
				}
			}
		} else {
			// Empty cube
			if (inside) {
				inside = false;
				prevVoxel = 0u;
			}

			no_more_cubes = dda_step(ddc);
		}

		if (stop || no_more_cubes) {
			break;
		}
	}

	// No transparent voxel found?
	if (first) {
		discard;
	}

	// Hit an opaque pixel or reached near zero transmittance?
	vec3 background = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	if (stop) {
		ALPHA = 1.0;
		ALBEDO = mix(paint, background, totalTrans);
	} else {
		// This is an approximation based on the "gray" ALPHA available.
		// Better would be to have proper support for colored transmittance in Godot.

		// Gray component of transmittance is used as alpha
		float gray = min(totalTrans.r, min(totalTrans.g, totalTrans.b));
		vec3 color = totalTrans - gray;
		ALPHA = 1.0 - gray;

		// Apply paint color with albedo
		ALBEDO = paint + color * background;
	}

	// Multiplier was hand tuned to match MagicaVoxel's lighting
	// See also the same constant in CubeLighting.cpp
	// FIXME: Turn this constant into a uniform
	EMISSION = totalEmission; // * 0.05; !!!
}
