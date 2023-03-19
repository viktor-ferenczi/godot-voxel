@tool
extends Node3D
class_name TexturedVoxelBox


# Voxel size to achieve (voxels are cubes, so the size is the same along each axis)
@export_range(0.01, 10.0, 0.01, "or_greater", "or_lesser") var voxel_size: float = 1.0:
	get:
		return voxel_size
	set(value):
		voxel_size = value
		update()

# See the texture parameters defined in TexturedSampler shader include
@export var size_in_cubes: Vector3i:
	get:
		return size_in_cubes
	set(value):
		size_in_cubes = value
		update()

# FIXME: Bad naming. Can be confused with Godot's Cubemap feature,
# while this is entirely different. Rename to something else.
@export var cube_map_texture: Texture2D:
	get:
		return cube_map_texture
	set(value):
		cube_map_texture = value
		update()

@export_range(1.0, 16.0, 0.125) var uv_scale: float = 16.0:
	get:
		return uv_scale
	set(value):
		uv_scale = value
		update()

@export var voxel_textures: CompressedTexture2DArray:
	get:
		return voxel_textures
	set(value):
		voxel_textures = value
		update()

@export var color_textures: CompressedTexture2DArray:
	get:
		return color_textures
	set(value):
		color_textures = value
		update()

@export var emission_textures: CompressedTexture2DArray:
	get:
		return emission_textures
	set(value):
		emission_textures = value
		update()

@export var normal_textures: CompressedTexture2DArray:
	get:
		return normal_textures
	set(value):
		normal_textures = value
		update()

@export var rsma_textures: CompressedTexture2DArray:
	get:
		return rsma_textures
	set(value):
		rsma_textures = value
		update()

func update():
	if is_ready:
		configure()


# True if _ready has completed
var is_ready: bool = false

# True if all the input variables are valid
var is_valid: bool = false

# Shader material for each of the opaque, transparent and shadow nodes.
# Separate nodes and materials are used, because the three rendering
# passes are optimized and treat transparent voxels differently.
# It also allows for debugging transparency and shadow issues
# by toggling the relevant nodes.
var shader_materials: Array[ShaderMaterial] = []


func _ready():
	# Collect references to the shader materials from each node
	shader_materials.append($Opaque.get_surface_override_material(0))
	shader_materials.append($Transparent.get_surface_override_material(0))
	shader_materials.append($Shadow.get_surface_override_material(0))

	# Allow for correct programmatic instancing
	$Opaque.owner = self
	$Transparent.owner = self
	$Shadow.owner = self

	configure()

	is_ready = true


func clear():
	is_valid = false
	size_in_cubes = Vector3i(0, 0, 0)
	cube_map_texture = null
	voxel_textures = null
	color_textures = null
	emission_textures = null
	normal_textures = null
	rsma_textures = null
	set_shader_parameters()


func configure():
	is_valid = false

	var is_incomplete = (
		cube_map_texture == null or
		voxel_textures == null or
		color_textures == null or
		emission_textures == null or
		normal_textures == null or
		rsma_textures == null
	)
	if is_incomplete:
		return

	var is_valid_size_in_cubes = (
		size_in_cubes[size_in_cubes.min_axis_index()] >= 1 and
		size_in_cubes[size_in_cubes.max_axis_index()] <= 16
	)
	if not is_valid_size_in_cubes:
		print("%s: Invalid size_in_cubes, must be between (1, 1, 1) and (16, 16, 16)" % [name])
		return

	var is_valid_cube_map = (
		size_in_cubes[size_in_cubes.min_axis_index()] >= 1 and
		size_in_cubes[size_in_cubes.max_axis_index()] <= 16 and
		cube_map_texture != null and
		#cube_map_texture.get_format() == Image.FORMAT_RGB8 and
		cube_map_texture.get_width() == 16 and
		cube_map_texture.get_height() == 256
	)
	if not is_valid_cube_map:
		print("%s: Invalid cube_map_texture, must be 16x256 FORMAT_RGB8" % [name])

	var cube_count = size_in_cubes.x * size_in_cubes.y * size_in_cubes.z
	var is_valid_voxel_textures = (
		voxel_textures != null and
		#voxel_textures.get_format() == Image.FORMAT_R8 and
		voxel_textures.get_width() == 256 and
		voxel_textures.get_height() == 16 and
		voxel_textures.get_layers() == cube_count
	)
	if not is_valid_voxel_textures:
		print("%s: Invalid voxel_textures, must be 256x16 FORMAT_R8 imported as W*H*D layers where size_in_cubes=(W, H, D)" % [name])

	var w = color_textures.get_width()
	var h = color_textures.get_height()
	var l = color_textures.get_layers()

	var is_valid_color_textures = (
		color_textures != null and
		#color_textures.get_format() == Image.FORMAT_RGBA8 and
		w >= 1 and
		w <= 512 and
		h >= 1 and
		h <= 512 and
		l >= 2 and
		l <= 256
	)
	if not is_valid_color_textures:
		print("%s: Invalid color_textures, must be FORMAT_RGBA8 imported as 2..256 layers" % [name])

	var is_valid_emission_textures = (
		emission_textures != null and
		#emission_textures.get_format() == Image.FORMAT_RGB8 and
		emission_textures.get_width() == w and
		emission_textures.get_height() == h and
		emission_textures.get_layers() == l
	)
	if not is_valid_emission_textures:
		print("%s: Invalid emission_textures, must be FORMAT_RGB8 imported as 2..256 layers" % [name])

	var is_valid_normal_textures = (
		normal_textures != null and
		#normal_textures.get_format() == Image.FORMAT_RGB8 and
		normal_textures.get_width() == w and
		normal_textures.get_height() == h and
		normal_textures.get_layers() == l
	)
	if not is_valid_normal_textures:
		print("%s: Invalid normal_textures, must be FORMAT_RGB8 imported as 2..256 layers" % [name])

	var is_valid_rsma_textures = (
		rsma_textures != null and
		#rsma_textures.get_format() == Image.FORMAT_RGBA8 and
		rsma_textures.get_width() == w and
		rsma_textures.get_height() == h and
		rsma_textures.get_layers() == l
	)
	if not is_valid_rsma_textures:
		print("%s: Invalid rsma_textures, must be FORMAT_RGBA8 imported as 2..256 layers" % [name])

	is_valid = (
		is_valid_cube_map and
		is_valid_voxel_textures and
		is_valid_color_textures and
		is_valid_emission_textures and
		is_valid_normal_textures and
		is_valid_rsma_textures
	)
	if not is_valid:
		print("Please see the template texture images under addons/voxel/Examples/Templates")
		return

	var scale = voxel_size * size_in_cubes * 16
	$Opaque.scale = scale
	$Transparent.scale = scale
	$Shadow.scale = scale

	set_shader_parameters()


func set_shader_parameters():
	for shader_material in shader_materials:
		shader_material.set_shader_parameter("size_in_cubes", size_in_cubes)
		shader_material.set_shader_parameter("cube_map_texture", cube_map_texture)
		shader_material.set_shader_parameter("uv_scale", uv_scale)
		shader_material.set_shader_parameter("voxel_textures", voxel_textures)
		shader_material.set_shader_parameter("color_textures", color_textures)
		shader_material.set_shader_parameter("emission_textures", emission_textures)
		shader_material.set_shader_parameter("normal_textures", normal_textures)
		shader_material.set_shader_parameter("rsma_textures", rsma_textures)
