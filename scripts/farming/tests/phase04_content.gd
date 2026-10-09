extends RefCounted
## Real content and real UI handlers; uses only the farmtest save path.
const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const CropManager := preload("res://scripts/farming/core/crops/crop_manager.gd")
const Foundation := preload("res://scripts/farming/tests/phase04_foundation.gd")


static func run(farm) -> Array[String]:
	var fails: Array[String] = []
	farm.crop_mgr.reset_all()
	farm.grid.reset()
	farm.clock.setup(farm._config)
	farm.inventory.setup(farm._config["start_inventory"])
	var categories := []
	for cid in farm._tool_crop_ids:
		categories.append(farm.crop_mgr.def_of(cid)["category"])
	Foundation.check(categories.has("herb") and categories.has("shrub") and categories.has("tree") and categories.has("fungus"),
		"四类真实配置登记为种子槽", fails)
	var origin := Vector2i(1,1)
	for dy in range(2):
		for dx in range(2):
			farm.grid.till(origin+Vector2i(dx,dy))
	farm._tool = farm._tool_crop_ids.find("jade_fruit_tree")+1
	farm.grid.prepare_medium(Vector2i(2,2),"fungal_bed")
	var seeds: int = farm.inventory.count("jade_fruit_tree_seed")
	var ap: int = farm.clock.ap
	farm._act_on(origin)
	Foundation.check(farm.inventory.count("jade_fruit_tree_seed")==seeds and farm.clock.ap==ap and farm.crop_mgr.crops.is_empty(),
		"真实果树混合介质拒绝且不扣种子/AP", fails)
	farm.grid.prepare_medium(Vector2i(2,2),"soil")
	farm._act_on(origin)
	var tree: Dictionary = farm.crop_mgr.instance_at(Vector2i(2,2))
	Foundation.check(tree.get("crop_id","")=="jade_fruit_tree" and farm.inventory.count("jade_fruit_tree_seed")==seeds-1 and
		farm.clock.ap==ap-farm.clock.cost_of("plant") and farm.grid.holder_cells(farm.crop_mgr.holder_of(tree.get("uid",-1))).size()==4,
		"真实果树播种扣一次种子/AP，四格共用实例",fails)
	var fungus_cell := Vector2i(4,1)
	farm.grid.till(fungus_cell)
	farm._tool = farm._tool_crop_ids.find("moon_cap")+1
	seeds = farm.inventory.count("moon_cap_seed")
	ap = farm.clock.ap
	farm._act_on(fungus_cell)
	Foundation.check(farm.crop_mgr.instance_at(fungus_cell).is_empty() and farm.clock.ap==ap and farm.inventory.count("moon_cap_seed")==seeds,
		"真实月华菇拒绝土壤，不扣种子/AP",fails)
	farm._cycle_medium(fungus_cell)
	farm._act_on(fungus_cell)
	Foundation.check(farm.crop_mgr.instance_at(fungus_cell).get("crop_id","")=="moon_cap" and farm.inventory.count("moon_cap_seed")==seeds-1,
		"真实月华菇在菌床播种",fails)
	for day in range(4):
		farm.clock.end_day()
	Foundation.check(farm.crop_mgr.can_harvest(fungus_cell)["ok"] and not farm.crop_mgr.can_harvest(origin)["ok"],
		"月华菇4天成熟，果树仍在生长",fails)
	for day in range(6):
		farm.clock.end_day()
	farm._save()
	farm.crop_mgr.reset_all()
	farm.grid.reset()
	farm.inventory.setup({})
	var loaded: bool = farm._load(true)
	Foundation.check(loaded and farm.crop_mgr.can_harvest(Vector2i(2,2))["ok"] and farm.crop_mgr.can_harvest(fungus_cell)["ok"] and
		farm.grid.medium_at(fungus_cell)=="fungal_bed" and farm.clock.total_days==10,
		"真实果树与菌菇存读档恢复实例/介质/库存/日期",fails)
	Foundation.check(farm.renderer.dynamic_atlas_cell(origin)!=Vector2i(-1,-1) and
		farm.renderer.dynamic_atlas_cell(Vector2i(2,2))!=Vector2i(-1,-1) and
		farm.renderer.dynamic_atlas_cell(fungus_cell)!=Vector2i(-1,-1),
		"播种及读档后已种植格仍保留动态耕地纹理",fails)
	var uid: int = int(farm.crop_mgr.instance_at(origin).get("uid",-1))
	var sprite = farm.crop_r._sprites.get(uid)
	Foundation.check(sprite!=null and sprite.visible and sprite.texture.get_size()==Vector2(128,192) and
		sprite.position==Vector2(128,192) and sprite.offset==Vector2(0,-96) and farm._ysort.y_sort_enabled,
		"果树大画布贴地锚点与Y-sort容器正确",fails)
	for harvest in range(3):
		farm._act_on(Vector2i(2,2))
		if harvest<2:
			for day in range(3):
				farm.clock.end_day()
	Foundation.check(farm.inventory.count("jade_fruit")>=9 and farm.crop_mgr.can_clear(origin)["ok"],
		"真实果树任意占地格采收3次、3天再生、产物入库并枯竭",fails)
	farm._tool=0
	farm._act_on(Vector2i(2,1))
	var cleared := true
	for dy in range(2):
		for dx in range(2):
			var cell := origin+Vector2i(dx,dy)
			cleared = cleared and farm.grid.state_at(cell)==LandGrid.State.TILLED and farm.grid.medium_at(cell)=="soil"
	Foundation.check(cleared and farm.crop_mgr.instance_at(origin).is_empty(),"果树任意格清理恢复四格土壤耕地",fails)
	farm._act_on(fungus_cell)
	Foundation.check(farm.inventory.count("moon_cap_flesh")>=1 and farm.crop_mgr.instance_at(fungus_cell).is_empty() and
		farm.grid.state_at(fungus_cell)==LandGrid.State.TILLED and farm.grid.medium_at(fungus_cell)=="fungal_bed",
		"月华菇采收产物入库，菌床保留可再次播种",fails)
	farm.crop_mgr.reset_all()
	farm.grid.reset()
	farm.renderer.refresh_dynamic_all()
	Foundation.check(farm.renderer.used_count("tilled")==0,"复位刷新清除旧动态耕地，不残留地块",fails)
	return fails
