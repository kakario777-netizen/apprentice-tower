extends SceneTree
# 3D 소품 모델(Quaternius, CC0)을 2D 화면용 그림으로 미리 구워 둔다(위에서 비스듬히 45°, 4방향).
# 사용: godot --path godot --script res://dev/render2d.gd -- out=res://sprites2d
# 결과: <이름>_<0|1|2|3>.png + sprites2d.json {이름: {ppt, n, a: [[ax, ay, w, h], ...]}}
const PPT := 48.0          # 한 타일(1 단위)이 그림에서 몇 px
const PITCH := 45.0
const SKIP := ["CommonTree", "Pine_", "Bush_", "Grass_", "Flower_", "Fern_", "Clover_", "Plant_", "DeadTree", "Mushroom", "Pebble", "Petal"]

func _init():
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var out: String = args.get("out", "res://sprites2d")
	var only: String = args.get("only", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var px := 512
	var vp := SubViewport.new(); vp.size = Vector2i(px, px); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.msaa_3d = Viewport.MSAA_4X
	get_root().add_child(vp)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = px / PPT
	vp.add_child(cam)
	var L := DirectionalLight3D.new(); L.rotation_degrees = Vector3(-55, 30, 0); L.light_energy = 1.15; vp.add_child(L)
	var L2 := DirectionalLight3D.new(); L2.rotation_degrees = Vector3(-25, -150, 0); L2.light_energy = .35; vp.add_child(L2)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.6, .58, .62); env.environment.ambient_light_energy = .9
	vp.add_child(env)
	var e := deg_to_rad(PITCH)
	var center := Vector3(0, .9, 0)
	await process_frame
	cam.look_at_from_position(center + Vector3(0, sin(e), cos(e)) * 40.0, center, Vector3.UP)
	var names: Array = []
	for f in DirAccess.get_files_at("res://models"):
		if not f.ends_with(".gltf"): continue
		var n := f.get_basename(); var skip := false
		for s in SKIP:
			if n.begins_with(s): skip = true
		if skip: continue
		if only != "" and not (n in only.split(",")): continue
		names.append(n)
	var meta := {}
	var holder := Node3D.new(); vp.add_child(holder)
	for i in 4: await process_frame
	for n in names:
		var md := Props3D.model(n, "prop", 1.0)
		holder.add_child(md)
		var rec: Array = []
		for k in 4:
			md.rotation.y = k * PI / 2
			for i in 2: await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			# 땅 위 원점이 그림 어디에 찍히는지
			var o: Vector2 = cam.unproject_position(Vector3.ZERO)
			var used := img.get_used_rect()
			if used.size.x <= 0:
				rec.append([0, 0, 1, 1]); continue
			used = used.grow(1).intersection(Rect2i(0, 0, px, px))
			var crop := img.get_region(used)
			crop.save_png(ProjectSettings.globalize_path("%s/%s_%d.png" % [out, n, k]))
			rec.append([o.x - used.position.x, o.y - used.position.y, used.size.x, used.size.y])
		meta[n] = {ppt = PPT, a = rec}
		md.queue_free()
		print("R2D ", n)
	var f := FileAccess.open(ProjectSettings.globalize_path(out + "/sprites2d.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta)); f.close()
	print("R2D done ", names.size())
	quit()
