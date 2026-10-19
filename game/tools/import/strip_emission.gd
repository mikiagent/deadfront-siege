@tool
extends EditorScenePostImport
## Post-import for the generated (Meshy) nature and resource GLBs, set as import_script in their
## .import files, which embed images uncompressed (gltf/embedded_image_handling=3).
## 1. Drops emission: Meshy copies the albedo into a full-strength emissive map, so crowns and
##    rocks glowed under the island light, and the map cost a fourth texture per prop.
## 2. Caps every texture at 512 px and re-encodes it as Basis Universal (UASTC + RDO), embedded
##    in the scene. Only textures a material still uses are saved, so the emissive map is gone
##    from the pack instead of shipping as an unused extracted file.
## No class_name: EditorScenePostImport only exists in the editor and tools/ is never exported.

const MAX_PX := 512
## Measured on tree-pine-a at 512 px: RDO 1.0 costs <= 1.3 dB PSNR and saves 1-24 % per map.
const RDO_LOSS := 1.0

var _encoded: Dictionary = {}  # source Texture2D -> its re-encoded texture

func _post_import(scene: Node) -> Object:
	# Keep compressed buffers so the scene saves them, without baking keep_compressed_buffer=true
	# into each texture (that would hold a second copy in RAM at runtime).
	# It is a process-wide static, so put back what the editor had for later imports.
	var was := PortableCompressedTexture2D.is_keeping_all_compressed_buffers()
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	_walk(scene)
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(was)
	return scene

func _walk(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi:
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				_fix(mi.mesh.surface_get_material(s))
		for s in mi.get_surface_override_material_count():
			_fix(mi.get_surface_override_material(s))
	for c in n.get_children():
		_walk(c)

func _fix(mat: Material) -> void:
	var m := mat as BaseMaterial3D
	if m == null:
		return
	m.emission_enabled = false
	m.emission_texture = null
	for p in BaseMaterial3D.TEXTURE_MAX:
		var param := p as BaseMaterial3D.TextureParam
		var tex := m.get_texture(param)
		if tex:
			m.set_texture(param, _shrink(tex, param == BaseMaterial3D.TEXTURE_NORMAL))

func _shrink(tex: Texture2D, normal_map: bool) -> Texture2D:
	if _encoded.has(tex):
		return _encoded[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var longest := maxi(img.get_width(), img.get_height())
	if longest > MAX_PX:
		var k := float(MAX_PX) / float(longest)
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps(normal_map)
	var out := PortableCompressedTexture2D.new()
	out.set_basisu_compressor_params(0, RDO_LOSS)
	out.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL, normal_map)
	out.resource_name = tex.resource_name
	_encoded[tex] = out
	return out
