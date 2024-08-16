@tool
extends Node3D

const DOC = """Builds a voxel box mesh

A voxel box contains N^3 voxels drawn by the fragment shader.

The mesh itself does not have any visual appearance and serves only as a 
reference frame for drawing voxels inside it. It has no normals, nor UVs, 
because they are provided by the fragment shader for each voxel.

Position: (0, 0, 0)
Size: (1, 1, 1)

The box consists of 12 triangles on a strip with 8 indexed vertices,
the most optimal way to run the fragment shader only for the pixels required.

The box is not centered to make voxel calculations in the shader simpler.
Interpolated vertex coordinates serve as voxel coordinates in model space.

The voxel resolution varies with the size of the voxel model as measured in
voxel cubes. Each voxel cube contains 16x16x16 voxels each, therefore the
voxel resulution is always divisible by 16 in each axis.

The actual size of voxels in determined by the voxel resolution and the
scaling of the voxel box by its user. For example a 48x32x16 voxel box must 
be scaled by Vector3(1.0, 1.5, 3.0) in the scene to produce cubical voxels.

"""

func _ready():
	$VoxelModel.mesh = create_cube()


func create_cube() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i in triangle_strip:
		var v = vertices[i]
		st.add_vertex(v)

	st.index()

	return st.commit()


const triangle_strip = [0, 1, 4, 5, 7, 1, 3, 0, 2, 4, 6, 7, 2, 3]


const vertices = [
	Vector3(0, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 1, 0),
	Vector3(0, 1, 1),
	Vector3(1, 0, 0),
	Vector3(1, 0, 1),
	Vector3(1, 1, 0),
	Vector3(1, 1, 1),
];
