# 모델 미리보기(개발용): 모든 models/*.gltf 를 줄지어 놓고 한 장 찍는다
extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	var root := Node3D.new(); get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.15, .15, .2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.5, .5, .6)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); root.add_child(sun)
	var names: Array = []
	for f in DirAccess.get_files_at("res://models"):
		if f.ends_with(".gltf"): names.append(f)
	names.sort()
	var cols := 10
	for i in names.size():
		var sc: PackedScene = load("res://models/" + names[i])
		var n: Node3D = sc.instantiate(); root.add_child(n)
		n.position = Vector3((i % cols) * 4.0, 0, (i / cols) * 5.0)
		var aabb := _aabb(n); print("SIZE ", names[i].get_basename(), " ", aabb.size, " ", aabb.position)
		var l := Label3D.new(); l.text = "%s\n%.1fx%.1fx%.1f" % [names[i].get_basename(), aabb.size.x, aabb.size.y, aabb.size.z]; l.font_size = 48; l.pixel_size = .006
		l.position = n.position + Vector3(0, -.3, 1.6); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(l)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.position = Vector3(18, 26, 30); cam.look_at(Vector3(18, 0, 9)); cam.fov = 55
	for k in 8: await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); quit()
func _aabb(n: Node) -> AABB:
	var a := AABB(); var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = c.global_transform * c.get_aabb()
		if first: a = b; first = false
		else: a = a.merge(b)
	return a
