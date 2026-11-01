extends SceneTree
# 사용: -- out=DIR yaws=0,90,180 pitch=30 clip=Z size=12 center=x,y,z
var args := {}
func _init():
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var vp := SubViewport.new(); vp.size = Vector2i(int(args.get("px", "512")), int(args.get("px", "512"))); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var sc = load("res://rabbit.fbx").instantiate(); vp.add_child(sc)
	var clip: float = float(args.get("clip", "-999"))
	var axis: String = args.get("axis", "z")
	var red: bool = args.get("red", "0") == "1"
	for m in _meshes(sc):
		var old: StandardMaterial3D = m.get_active_material(0)
		var sm := ShaderMaterial.new(); var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled%s;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float clip = -999.0;
uniform float scissor = 0.5;
uniform bool red = false;
uniform bool body = true;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// 목 아래(몸통)는 지우되 부드럽게 사라지게, 귀는 남김
	float keep = max(smoothstep(clip, clip + 1.4, wp.z), step(12.0, wp.y));
	if (clip < -100.0) keep = 1.0;
	vec4 c = texture(tex, UV);
	if (c.a < scissor) discard;
	float lum = dot(c.rgb, vec3(.3, .59, .11));
	vec3 col = c.rgb;
	bool eye = UV.x > .72 && UV.x < .78 && ((UV.y > .735 && UV.y < .79) || (UV.y > .56 && UV.y < .612));
	if (red && body && eye && lum < .2) { col = vec3(.95, .05, .03); EMISSION = vec3(1.4, .05, .02); }
	ALBEDO = col;
	ALPHA = keep * (body ? 1.0 : c.a);
	ROUGHNESS = .85;
}
""" % [", depth_prepass_alpha"]
		sm.shader = sh; sm.set_shader_parameter("tex", old.albedo_texture if old else null); sm.set_shader_parameter("clip", clip)
		sm.set_shader_parameter("scissor", .35 if m.name == "Fur" else .01); sm.set_shader_parameter("body", m.name != "Fur"); sm.set_shader_parameter("red", red)
		m.material_override = sm
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = float(args.get("size", "22"))
	vp.add_child(cam)
	var L := DirectionalLight3D.new(); L.rotation_degrees = Vector3(-50, 35, 0); L.light_energy = 1.25; vp.add_child(L)
	var L2 := DirectionalLight3D.new(); L2.rotation_degrees = Vector3(-20, -140, 0); L2.light_energy = .35; vp.add_child(L2)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.55, .55, .6); env.environment.ambient_light_energy = .8
	vp.add_child(env)
	var c: PackedStringArray = String(args.get("center", "0,7,5")).split(","); var center := Vector3(float(c[0]), float(c[1]), float(c[2]))
	var pitch: float = deg_to_rad(float(args.get("pitch", "25")))
	DirAccess.make_dir_recursive_absolute(args.get("out", "/tmp/r"))
	for y in (["warm"] + Array(String(args.get("yaws", "0,90,180,270")).split(","))):
		if y == "warm":
			cam.position = Vector3(0, 10, 60); cam.look_at(Vector3(0, 10, 0), Vector3.UP)
			for i in 6: await process_frame
			continue
		var yaw: float = deg_to_rad(float(y) + float(args.get("yoff", "0")))
		var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		cam.position = center + dir * 60.0; cam.look_at(center, Vector3.UP)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/y%s.png" % [args.get("out", "/tmp/r"), y])
	quit()
func _meshes(n):
	var out = []
	if n is MeshInstance3D: out.append(n)
	for ch in n.get_children(): out += _meshes(ch)
	return out
