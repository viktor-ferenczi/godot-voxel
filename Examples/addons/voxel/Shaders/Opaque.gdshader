shader_type spatial;
render_mode skip_vertex_transform;
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

	bool found = false;
	bool no_more_cubes = false;
	for(int csteps=0; csteps < 49; csteps++) {
		uint layer;
		bool has_opaque;

		// Consider only cubes with any opaque voxels
		if (get_cube(ddc.position, layer, has_opaque) && has_opaque) {

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

					// Consider only opaque voxels, transparent ones are skipped
					if (get_voxel(ddv.position, layer, tpos, voxel, color, opaque) && opaque) {

						// Ray intersection with the voxel's face (plane) in model coordinates
						vec3 hit = origin + dda_voxel_face_hit(ddv, vec3(1.0 / 16.0)) * MODEL_SIZE_REC;

						// Depth for intersection and lighting
						vec3 light_vertex = calc_vertex(hit, PROJECTION_MATRIX, _MODELVIEW_MATRIX, depth);

						// Consider only voxels in front of the screen
						if (light_vertex.z < 0.0) {
							DEPTH = depth;
							LIGHT_VERTEX = light_vertex;

							// Surface normals
							dda_voxel_face_normals(ddv, NORMALS, NORMAL, TANGENT, BINORMAL);

							// UV for texturing
							uint face;
							vec2 uv = dda_voxel_face_uv(ddv, model_size, hit, face);

							// Material
							vec4 rsma;
							vec3 normal_map;
							get_opaque_material(tpos, voxel, color, face, uv, ALBEDO, EMISSION, normal_map, rsma);
							NORMAL_MAP = vec3(normal_map.xy, 0.0);
							NORMAL_MAP_DEPTH = normal_map.z;
							ROUGHNESS = rsma.r;
							SPECULAR = rsma.g;
							METALLIC = rsma.b;
							AO = rsma.a;

							// Stop the ray on the first opaque surface
							found = true;
							break;
						}
					}

					if (dda_step(ddv)) {
						break;
					}
				}
			}
		} else {
			no_more_cubes = dda_step(ddc);
		}

		if (found || no_more_cubes) {
			break;
		}
	}

	if (!found) {
		discard;
	}
}
