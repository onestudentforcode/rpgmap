extends SceneTree
## P10.9 设施回填验证：默认场景激活新设施美术、纹理可解码、锚点契约、
## profile 切换原子性与玩法快照不变。镜像 run_p109_plants.gd 的结构。
const Scene := preload("res://scenes/farming/farm_p8.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const FacilityVisuals := preload("res://scripts/farming/p8/p8_facility_visuals.gd")
const P109_MANIFEST := "res://assets/farming/p109/runtime/facility_manifest.json"
const LEGACY_MANIFEST := "res://assets/farming/facilities/facility_manifest.json"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	var shell = Scene.instantiate()
	var directory := "res://.art-work/p109/tests/fac%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	check(shell.facility_profile == "p109", "default main scene activates new facility art")
	check(shell.facility_visuals.diagnostics.is_empty(), "all facility textures decode")
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	# p109 覆盖的25项 + legacy 沿用条目 = legacy 全量键
	var legacy := FacilityVisuals.new(LEGACY_MANIFEST)
	for ident in legacy.facilities:
		check(shell.facility_visuals.facilities.has(ident), "facility present " + ident)
	# 覆盖项运行文件与哈希
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(P109_MANIFEST))
	var p109_ids: Array = []
	for ident in parsed["facilities"]:
		p109_ids.append(ident)
		var data: Dictionary = parsed["facilities"][ident]
		check(String(shell.facility_visuals.facilities[ident]["path"]) == String(data["path"]), "entry uses p109 body " + ident)
		check(FileAccess.get_sha256(String(data["path"])) == String(data["sha256"]), "runtime hash " + ident)
		var entry: Dictionary = shell.facility_visuals.facilities[ident]
		var fp: Array = entry["footprint"]
		var draw: Array = entry["draw_size"]
		check(float(draw[0]) >= float(fp[0]) * 100.0, "display size keeps cell readable " + ident)
	# 锚点契约：visual() 返回的 rect 尺寸与 draw_size 一致
	for ident in ["small_bed","dispatch_station","rock_breaking_yard"]:
		var entry: Dictionary = shell.facility_visuals.facilities[ident]
		var fp: Array = entry["footprint"]
		var cell := Rect2(Vector2(3, 4), Vector2(float(fp[0]), float(fp[1])))
		var visual: Dictionary = shell.facility_visuals.visual(ident, cell)
		check(not visual.is_empty(), "visual resolves " + ident)
		check(visual["rect"].size == Vector2(float(entry["draw_size"][0]), float(entry["draw_size"][1])) * float(entry["scale_multiplier"]), "draw size contract " + ident)
	check(p109_ids.size() == 25, "25 facilities replaced")
	# 切换原子性 / 回退 / 缓存恢复
	var active = shell.facility_visuals
	check(not shell.configure_facility_profile("invalid")["ok"] and shell.facility_visuals == active, "unknown profile retained atomically")
	check(shell.configure_facility_profile("legacy")["ok"], "legacy rollback")
	check(shell.configure_facility_profile("p109")["ok"] and shell.facility_visuals != active, "new profile restored")
	check(shell.world.to_snapshot() == before, "profile changes preserve complete gameplay snapshot")
	for failure in failures: printerr(failure)
	print("P109 FACILITIES %s: %d checks" % ["OK" if failures.is_empty() else "FAILED", checks])
	quit(0 if failures.is_empty() else 1)
