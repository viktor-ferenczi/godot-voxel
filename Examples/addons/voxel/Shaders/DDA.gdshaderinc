//===========================================================================
// DDA algorithm to visit cells of a 16x16x16 cube grid intersected by a 3D line
//
// See: A Fast Voxel Traversal Algorithm for Ray Tracing - Amanatides, Woo
// https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
//
// The grid is axis aligned and starts at the origin. Cell size is 1x1x1
//===========================================================================


// Minimum safe absolute value of a highp float to avoid division by zero
const float EPSILON = 1.0 / 65536.0;


struct DDA {
	// Direction of the ray (should be near normalized)
	vec3 ray;

	// Entry point of the ray
	vec3 entry;

	// Position where the ray may leave
	ivec3 limit;

	// DDA increment
	vec3 increment;

	// DDA offset
	vec3 offset;

	// Current cell
	ivec3 position;

	// Non-zero axis of the face normal on the currently hit cell
	bvec3 mask;
};


/* Initializes the DDA algorithm for a unit cube of voxels
res: Number of voxels in the unit cube
entry: Entry point of the ray, must be on the surface of the unit cube
ray: Direction of the ray (normalized)
ray_rec: Reciprocal ray vector (optimization)
*/
void dda_init(out DDA dda, ivec3 res, const vec3 entry, const vec3 ray, const vec3 ray_rec) {
	dda.ray = ray;
	dda.entry = entry;

	ivec3 positive = ivec3(greaterThanEqual(ray, vec3(0.0)));
	dda.limit = positive * (res + 1) - 1;
	vec3 entry_coord = entry * vec3(res);
	// FIXME: The lower clamping may be optimized out
	dda.position = clamp(ivec3(entry_coord), ivec3(0), res - 1);

	vec3 fractional = entry_coord - vec3(dda.position);
	vec3 res_rec = 1.0 / vec3(res);
	dda.increment = abs(ray_rec) * res_rec;
	dda.offset = (vec3(positive) - fractional) * ray_rec * res_rec;

	vec3 v = abs(entry - 0.5);
	dda.mask = greaterThanEqual(v.xyz, max(v.yzx, v.zxy));
}


// Moves to the next voxel along the ray, returns true on leaving the cell grid
bool dda_step(inout DDA dda) {
	dda.mask = lessThanEqual(dda.offset.xyz, min(dda.offset.yzx, dda.offset.zxy));
	dda.offset += dda.increment * vec3(dda.mask);
	dda.position += ivec3(sign(dda.ray)) * ivec3(dda.mask);
	return any(equal(dda.position, dda.limit));
}


// Returns the hit point of the ray on the voxel at the current position
vec3 dda_voxel_face_hit(const DDA dda, vec3 res_rec) {
	vec3 face_normal = vec3(dda.mask);
	vec3 negative = 0.5 * (1.0 - sign(dda.ray));
	float t = dot(face_normal, (vec3(dda.position) + negative) * res_rec - dda.entry) / dot(face_normal, dda.ray);
	return dda.entry + dda.ray * t;
}


// Returns UV texture coordinates by hit point for use on the voxel face
vec2 dda_voxel_face_uv(const DDA dda, ivec3 model_size, const vec3 hit, out uint face) {
	vec3 shit = hit * vec3(model_size);
	vec3 sinv = vec3(model_size) - shit;

	if (dda.mask.x) {
		face = dda.ray.x < 0.0 ? 1u : 0u;
		return vec2(dda.ray.x < 0.0 ? sinv.z : shit.z, sinv.y);
	}

	if (dda.mask.y) {
		face = dda.ray.y < 0.0 ? 3u : 2u;
		return vec2(dda.ray.y < 0.0 ? shit.x : sinv.x, shit.z);
	}

	face = dda.ray.z < 0.0 ? 5u : 4u;
	return vec2(dda.ray.z < 0.0 ? shit.x : sinv.x, sinv.y);
}


// Returns voxel face normals
void dda_voxel_face_normals(const DDA dda, const mat3 normals, out vec3 normal, out vec3 tangent, out vec3 binormal) {
	vec3 direction = sign(dda.ray);

	if (dda.mask.x) {
		normal = -direction.x * normals[0];
		tangent = direction.x * normals[2];
		binormal = -normals[1];
		return;
	}

	if (dda.mask.y) {
		normal = -direction.y * normals[1];
		tangent = -direction.y * normals[0];
		binormal = normals[2];
		return;
	}

	normal = -direction.z * normals[2];
	tangent = direction.z * normals[0];
	binormal = -normals[1];
}


// Second layer DDA initialization
void dda_init_inner(out DDA inner, const DDA outer, ivec3 outer_res, vec3 outer_res_rec, const vec3 ray, const vec3 ray_rec, out vec3 origin) {
	ivec3 outer_pos = outer.position;
	origin = vec3(outer_pos) * outer_res_rec;
	vec3 outer_hit = dda_voxel_face_hit(outer, outer_res_rec) * vec3(outer_res) - vec3(outer_pos);
	vec3 inner_ray = ray * vec3(outer_res);
	vec3 inner_ray_rec = ray_rec * outer_res_rec;
	dda_init(inner, ivec3(16), outer_hit, inner_ray, inner_ray_rec);
}


//===========================================================================
// Generic utility functions
//===========================================================================


// Ensures a minimum asbsolute value to avoid division by zero errors
vec3 safe_vector(vec3 v) {
	return sign(v) * max(vec3(EPSILON), abs(v));
}


// Returns the front face ray intersection from a back one
// on a unit cube: (0, 0, 0) .. (1, 1, 1)
vec3 to_front_face(const vec3 back, const vec3 ray, const vec3 ray_rec) {
	vec3 negative = 0.5 * (1.0 - sign(ray));
	vec3 tv = (back - negative) * ray_rec;
	float t = min(tv.x, min(tv.y, tv.z));
	return back - t * ray;
}


// Returns the back face ray intersection from a front one
// on a unit cube: (0, 0, 0) .. (1, 1, 1)
vec3 to_back_face(const vec3 front, const vec3 ray, const vec3 ray_rec) {
	vec3 positive = 0.5 * (1.0 + sign(ray));
	vec3 tv = (front - positive) * ray_rec;
	float t = min(tv.x, min(tv.y, tv.z));
	return front + t * ray;
}


// Returns the vertex position in view space corresponding to a point in model space.
// The z component of the vertex position in view space is the linear depth, where zero is the screen.
// It also returns the non-linear depth for use in the Z buffer, return this value in DEPTH.
vec3 calc_vertex(const vec3 model_point, mat4 projection_matrix, mat4 modelview_matrix, out float depth) {
	vec4 viewPos = modelview_matrix * vec4(model_point, 1.0);
	vec4 ndc = projection_matrix * viewPos;
	depth = ndc.z / ndc.w;
	return viewPos.xyz / viewPos.w;
}
