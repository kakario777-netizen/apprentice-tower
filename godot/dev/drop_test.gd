extends SceneTree
func _initialize() -> void:
	var g := Game.new()
	g.G = g.fresh_g("norm"); g.P = g.fresh_p()
	for f in [1, 10, 30, 50, 70, 95]:
		g.G.floor = f
		var c := {}
		for i in 100000: var r := g.roll_rarity(); c[r] = c.get(r, 0) + 1
		var per := {}
		for k in c.keys(): per[k] = "%.2f%%" % (c[k] / 1000.0)
		print(f, " ", per)
	quit()
