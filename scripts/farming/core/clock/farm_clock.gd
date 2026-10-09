extends RefCounted
## 游戏时间（phase-02 §2，master-plan v1.1 任务 2.3）：24 时节 × 15 天 × 24 行动点。
## 只存 total_days 与 ap；时节/天/年全部派生；按天离散推进（day_changed 事件）。
## 消费方以 preload 引用（不依赖全局类缓存）。

signal day_changed(total_days: int)

var terms_per_year := 24
var days_per_term := 15
var ap_per_day := 24
var ap_costs: Dictionary = {}
var term_names: Array = []
var total_days := 0  # 已过去的天数；当前是第 total_days+1 天
var ap := 24


func setup(config: Dictionary) -> void:
	var t: Dictionary = config.get("time", {})
	terms_per_year = int(t.get("terms_per_year", 24))
	days_per_term = int(t.get("days_per_term", 15))
	ap_per_day = int(t.get("ap_per_day", 24))
	ap_costs = config.get("ap_costs", {})
	term_names = config.get("term_names", [])
	total_days = 0
	ap = ap_per_day


func cost_of(action: String) -> int:
	return int(ap_costs.get(action, 1))


func year() -> int:
	return total_days / (terms_per_year * days_per_term) + 1


func term_index() -> int:
	return (total_days % (terms_per_year * days_per_term)) / days_per_term


func term_name() -> String:
	if term_names.is_empty():
		return "时节%d" % (term_index() + 1)
	return String(term_names[term_index()])


func day_in_term() -> int:
	return total_days % days_per_term + 1


func can_spend(n: int) -> bool:
	return ap >= n


## 消耗行动点；归零自动进入次日（phase-02 决策 P2-B）。
func spend(n: int) -> bool:
	if not can_spend(n):
		return false
	ap -= n
	if ap <= 0:
		end_day()
	return true


## 进入次日：行动点重置，发 day_changed → 作物按天推进。
func end_day() -> void:
	total_days += 1
	ap = ap_per_day
	day_changed.emit(total_days)


func describe() -> String:
	return "%s · 第 %d 天（第 %d 年） · 行动点 %d/%d" % [
		term_name(), day_in_term(), year(), ap, ap_per_day]


func to_save() -> Dictionary:
	return {"total_days": total_days, "ap": ap}


func apply_save(d: Dictionary) -> void:
	total_days = int(d.get("total_days", 0))
	ap = int(d.get("ap", ap_per_day))
