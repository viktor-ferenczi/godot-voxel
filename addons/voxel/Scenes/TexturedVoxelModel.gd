@tool
extends Node3D
class_name TexturedVoxelModel


@export_range(0.01, 10.0, 0.01, "or_greater", "or_lesser") var voxel_size: float = 1.0:
	get:
		return voxel_size
	set(value):
		voxel_size = value
		update()

# Texture UV scale: 16.0 to cover a single voxel with the texture
@export_range(1.0, 16.0, 0.125) var uv_scale: float = 16.0:
	get:
		return uv_scale
	set(value):
		uv_scale = value
		update()

# Number of voxel cubes (16x16x16 voxels each) in the model along each axis
# Model size in individual voxels is 16 times larger than this vector.
@export var model_size: Vector3i:
	get:
		return model_size
	set(value):
		model_size = value
		update()

# Coarse grained voxel cube data (level-1 DDA)
# 256 x 16, RGB8
@export var model_texture: Texture2D:
	get:
		return model_texture
	set(value):
		model_texture = value
		update()

# Fine grained voxel data (level-2 DDA)
# 256 x 16 x N, R8
@export var voxel_textures: CompressedTexture2DArray:
	get:
		return voxel_textures
	set(value):
		voxel_textures = value
		update()

# Palette defining what texture to render for each of the voxel values.
# The first row is unused, because that corresponds to the empty voxel (zero).
# Each row configures all 6 faces for the given voxel value.
# 6 x 256, RGBA8
@export var palette_texture: Texture2D:
	get:
		return palette_texture
	set(value):
		palette_texture = value
		update()

# Surface color for opaque, transmittance for transparent voxels (RGBA)
@export var color_textures: CompressedTexture2DArray:
	get:
		return color_textures
	set(value):
		color_textures = value
		update()

# Surface emission for opaque, volumetric emission for transparent voxels (RGB)
@export var emission_textures: CompressedTexture2DArray:
	get:
		return emission_textures
	set(value):
		emission_textures = value
		update()

# Normal map (XY) and depth (Z)
@export var normal_textures: CompressedTexture2DArray:
	get:
		return normal_textures
	set(value):
		normal_textures = value
		update()

# RSMA: Roughness (R), Specular (G), Metallic (B), Ambient occlusion (A)
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

	# Configure on adding to the scene tree
	configure()

	# Allow for reconfiguration on property changes
	is_ready = true


# Clear for reuse in a pool
func clear():
	model_texture = null
	voxel_textures = null
	palette_texture = null
	color_textures = null
	emission_textures = null
	normal_textures = null
	rsma_textures = null
	model_size = Vector3i(0, 0, 0)
	voxel_size = 1.0
	uv_scale = 16.0
	set_node_scales()
	set_shader_parameters()


func configure():
	var is_incomplete = (
		model_texture == null or
		voxel_textures == null or
		palette_texture == null or
		color_textures == null or
		emission_textures == null or
		normal_textures == null or
		rsma_textures == null
	)
	if is_incomplete:
		show_nodes(false)
		return

	var is_valid_size_in_cubes: bool = (
		model_size[model_size.min_axis_index()] >= 1 and
		model_size[model_size.max_axis_index()] <= 16
	)

	if Engine.is_editor_hint():
		if not is_valid_size_in_cubes:
			print("%s: Invalid model_size. Must be between (1, 1, 1) and (16, 16, 16)" % [name])
		elif not expensive_verifications():
			show_nodes(false)
			return

	if not is_valid_size_in_cubes:
		show_nodes(false)
		return

	set_node_scales()
	set_shader_parameters()
	show_nodes(true)


func set_node_scales():
	var scale = voxel_size * model_size * 16
	$Opaque.scale = scale
	$Transparent.scale = scale
	$Shadow.scale = scale


func set_shader_parameters():
	for shader_material in shader_materials:
		shader_material.set_shader_parameter("uv_scale", uv_scale)
		shader_material.set_shader_parameter("model_size", model_size)
		shader_material.set_shader_parameter("model_texture", model_texture)
		shader_material.set_shader_parameter("voxel_textures", voxel_textures)
		shader_material.set_shader_parameter("palette_texture", palette_texture)
		shader_material.set_shader_parameter("color_textures", color_textures)
		shader_material.set_shader_parameter("emission_textures", emission_textures)
		shader_material.set_shader_parameter("normal_textures", normal_textures)
		shader_material.set_shader_parameter("rsma_textures", rsma_textures)


func show_nodes(visible):
	$Opaque.visible = visible
	$Transparent.visible = visible
	$Shadow.visible = visible


func expensive_verifications():
	var model_image: Image = model_texture.get_image()
	var is_valid_model: bool = (
		model_image.get_format() == Image.FORMAT_RGB8 and
		not model_image.is_compressed() and
		model_texture.get_width() == 256 and
		model_texture.get_height() == 16
	)
	if not is_valid_model:
		print("%s: Invalid model_texture. Must be 256x16 FORMAT_RGB8" % [name])

	var voxel_cube_0: Image = voxel_textures.get_layer_data(0)
	var is_valid_voxel: bool = (
		not voxel_cube_0.is_compressed() and
		voxel_textures.get_width() == 256 and
		voxel_textures.get_height() == 16
	)
	if not is_valid_voxel:
		print("%s: Invalid voxel_textures. Must be 256x16xN FORMAT_R8" % [name])

	var palette_image = palette_texture.get_image()
	var is_valid_palette: bool = (
		palette_image.get_format() == Image.FORMAT_RGB8 and
		not palette_image.is_compressed() and
		palette_texture.get_width() == 6 and
		palette_texture.get_height() == 256
	)
	if not is_valid_model:
		print("%s: Invalid palette_texture. Must be 6x256 FORMAT_RGBA8" % [name])

	return is_valid_model and is_valid_voxel and is_valid_palette
