"""Reconcile real P8 business runs; complete coverage is mandatory by default."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INCOME = ("sales_revenue", "order_revenue")
EXPENSE = ("purchase_spend", "construction_spend", "labour_spend")
ADVANCED = {"dew_soup", "fire_paste", "earth_pill", "gold_food"}
IRON = {"iron_ore": 3, "crushed_ore": 2, "ore_concentrate": 6, "iron_ingot": 6,
        "mineral_feed": 2, "steel_wool": 2, "gold_food": 6}
LEGITIMATE_OUT = {"养殖投喂", "净化启动", "加工投料", "市场出售", "建设材料", "播种投料", "施肥", "水场换水", "浇水", "特殊投料", "研究样本", "菌毯培养", "蜂群饲喂", "订单交付", "设备维护", "设备燃油"}
LEGITIMATE_IN = {"市场采购", "资源采集", "采收收获", "采花收获", "加工收取", "养殖收取", "水场换水"}

def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_lines(path: Path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]

def inside(cell, rect):
    return rect[0] <= cell[0] < rect[0]+rect[2] and rect[1] <= cell[1] < rect[1]+rect[3]

def balance(ledger: dict) -> Counter:
    stock = Counter(ledger["opening"])
    for key, sign in (("inflows", 1), ("outflows", -1)):
        for item, reasons in ledger[key].items():
            assert reasons.keys() <= (LEGITIMATE_IN if sign > 0 else LEGITIMATE_OUT), ("unrecognised flow", item, reasons)
            assert all(type(qty) in (int, float) and qty > 0 and qty == int(qty) for qty in reasons.values())
            stock[item] += sign * sum(reasons.values())
    assert all(qty >= 0 for qty in stock.values()), "negative inventory"
    assert stock == Counter(ledger["closing"]), ("inventory balance", ledger["day"])
    return stock

def reconcile(directory: Path, require_complete: bool = True) -> dict:
    summary = read_json(directory / "summary.json")
    assert not summary["failures"] and summary["checks"] > 0, summary["failures"]
    manifest = read_json(directory / "manifest.json")
    assert {"content/farming/baked/p8/production.json", "content/farming/baked/maps/farm_02.json",
            "scripts/farming/tests/run_p8_playtest.gd"} <= manifest.keys(), "incomplete manifest"
    for name, digest in manifest.items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, ("source changed", name)
    catalog = read_json(ROOT / "content/farming/baked/p8/production.json")
    config = catalog["config"]
    expansion = read_json(ROOT / "content/farming/baked/p8/expansion.json")
    parcels = {p['id']: p for p in expansion['parcels']}
    horizon, initial = summary["settings"]["days"], summary["settings"]["initial_currency"]
    assert 90 <= horizon <= 180 and 60 <= initial <= 120, "relaxation exceeds agreed bounds"
    assert config["ap_per_day"] == 24 and config["initial_primeval_stones"] == initial
    items = {r["id"]: r for r in catalog["resources"]}
    crops = {r["id"]: r for r in catalog["crops"]}
    recipes = {r["id"]: r for r in catalog["recipes"]}
    species = {r["id"]: r for r in catalog["livestock"]}
    facilities = {r["id"]: r for r in catalog["facilities"]}
    projects = {r["id"] for r in catalog["research"]}
    required = {r["id"] for r in catalog["recipes"] if r.get("research")}
    routes = summary["routes"]
    if require_complete: assert set(routes) == {"A", "B"}, "complete audit requires two independent routes"
    result = {"settings": summary["settings"], "mode": "complete" if require_complete else "diagnostic", "routes": {}}
    all_claims, all_consumers = set(), set()
    for route in sorted(routes):
        days = read_lines(directory / f"{route}-days.jsonl")
        assert [r["day"] for r in days] == list(range(1, horizon + 2)), (route, "missing day")
        assert days[0]["ledger"]["opening"] == config["start_inventory"], "injected starting stock"
        cash, inventory, wages = initial, None, 0
        delivered, processed = Counter(), Counter()
        shared_days, auto_steps, inflows, outflows = [], Counter(), {}, {}
        for row in days:
            day, ledger = row["day"] - 1, row["ledger"]
            assert ledger["day"] == day
            if inventory is not None: assert Counter(ledger["opening"]) == inventory, "stock continuity"
            inventory = balance(ledger)
            opening = row["opening"]
            assert opening["day"] == day + 1 and Counter(opening["opening"]) == inventory
            balance(opening)  # opening device costs belong to the next day's book
            journal = row["journal"]
            cash += sum(journal[k] for k in INCOME) - sum(journal[k] for k in EXPENSE)
            assert cash == row["cash"], (route, day, "cash balance")
            roster = row["workers"]["workers"]
            assert row["workers"]["day"] == day
            assert journal["labour_spend"] == sum(w["fee"] for w in roster) == sum(w["success"] for w in roster)
            for worker in roster:
                steps = sum(sum(f["steps"].values()) for f in worker["facilities"])
                assert steps + sum(worker["counts"].values()) == worker["success"]
                assert worker["success"] <= config["workers"]["daily_work_limit"]
                assert worker["fee"] <= (6 if worker["worker_id"] == 1 else 12), "shared budget exceeded"
                if steps and worker["counts"].get("source", 0) and day < horizon: shared_days.append(day + 1)
                for facility in worker["facilities"]: auto_steps.update(facility["steps"])
            for habitat in row["husbandry"]["habitats"]:
                gate = species[habitat["species_id"]].get("research")
                assert not habitat["individuals"] or not gate or gate in row["research"]["completed"], "locked species"
            if day < horizon:
                wages += journal["labour_spend"]; delivered.update(journal["delivered_items"]); processed.update(journal["processed"])
            inflows[day] = Counter({i: sum(v.values()) for i, v in ledger["inflows"].items()})
            outflows[day] = Counter({i: sum(v.values()) for i, v in ledger["outflows"].items()})
        failures, orders, payout, first_income, reinvested = Counter(), set(), 0, None, False
        for action in read_lines(directory / f"{route}-actions.jsonl"):
            assert 0 <= action["ap_before"] <= 24 and 0 <= action["ap_after"] <= 24
            receipt = action["result"]
            if not receipt.get("ok", True): failures[receipt.get("reason", "unknown")] += 1
            if receipt.get("ok") and "order_id" in receipt:
                assert receipt["order_id"] not in orders, "duplicate order settlement"
                orders.add(receipt["order_id"]); payout += receipt["quote"]["payout"]
                if receipt["quote"]["item_id"] in {"honey", "refined_oil", "nectar", *ADVANCED}:
                    first_income = action["day"] if first_income is None else first_income
            if first_income is not None and action["day"] > first_income and receipt.get("ok") \
                    and receipt.get("item_id") in {"raw_wood", "twig", "golden_wheat_seed", "grass_seed", "wood_decay_spawn"} \
                    and "buy" in action["action"]: reinvested = True
        assert not any("行动点不足" in reason for reason in failures), "overdrawn player AP"
        receipts = read_lines(directory / f"{route}-receipts.jsonl")
        assert [r["sequence"] for r in receipts] == list(range(1, len(receipts) + 1)), "receipt sequence gap"
        starts, claims, consumed = {}, Counter(), {}
        # A last-AP action can export its start after the automatic settlement.
        for r in receipts:
            if r["kind"] in {"batch", "cycle"} and r["stage"] == "start":
                key = (r["kind"], r["uid"], r["batch_id"])
                assert key not in starts, "duplicate batch start"
                starts[key] = r
        spent, issued = defaultdict(Counter), defaultdict(Counter)
        flower_use, flower_users, pollinated, device_use = Counter(), Counter(), set(), Counter()
        water_changes, lamp_days, lit_draws, automatic_starts, claimed_keys = set(), set(), 0, 0, set()
        def coverage(day, uid, margin):
            facility = next(f for f in days[day]["facilities"] if f["uid"] == uid)
            x, y = facility["origin"]
            width, height = facilities[facility["facility_id"]]["footprint"]
            return [x-margin, y-margin, width+2*margin, height+2*margin]
        def natural_light(cell):
            light = config["light"]
            return next((region["level"] for region in light["regions"] if inside(cell, region["rect"])), light["default"])
        for r in receipts:
            day, kind = r["day"], r["kind"]
            stage = "purchase" if kind == "expansion" else r["stage"]
            if day >= horizon: continue
            assert 0 <= day < horizon
            if kind in {"batch", "cycle"}:
                rid = r["recipe"]
                if rid in recipes: definition = recipes[rid]
                else:
                    definition = next(d for d in species[r["species"]]["special_diets"] if d["id"] == rid)
                    definition = {**definition, "outputs": definition.get("outputs", species[r["species"]]["outputs"])}
                assert r["inputs"] == definition["inputs"] and r["outputs"] == definition["outputs"], (rid, "wrong recipe receipt")
                gate = definition.get("research")
                assert not gate or gate in days[day]["research"]["completed"], (rid, "research bypass")
                assert sum(IRON.get(i, 0)*q for i, q in r["outputs"].items()) <= sum(IRON.get(i, 0)*q for i, q in r["inputs"].items()), (rid, "created iron")
                if stage == "start":
                    spent[day].update(r["inputs"])
                    if kind == "batch" and r["operator"] == "worker":
                        policy = r["strategy"]
                        assert policy["enabled"] and policy["recipe_id"] == rid
                        assert r["effective_before"] < policy["target_qty"], "automatic start above target"
                        for item, qty in r["inputs"].items():
                            assert r["stock_before"].get(item, 0)-qty >= r["reserves"].get(item, 0), "automatic reserve violation"
                        automatic_starts += 1
                elif stage == "claim":
                    key = (kind, r["uid"], r["batch_id"])
                    assert key in starts and key not in claimed_keys, "missing or duplicate claim"
                    paid = starts[key]
                    assert all(r[k] == paid[k] for k in ("recipe", "inputs", "outputs")) and day >= paid["day"], "changed paid batch"
                    claimed_keys.add(key); issued[day].update(r["outputs"]); claims[rid] += 1
                    # Shared stock has no lots. Require a later real outflow of an
                    # actual output, never infer consumption from a final counter.
                    uses = {item: next((d+1 for d in range(day+1, horizon) if outflows[d][item] > 0), None) for item in r["outputs"]}
                    if all(uses.values()): consumed.setdefault(rid, uses)
            elif kind == "automation" and r["started"]:
                policy = r["strategy"]
                habitat = next(h for h in days[day]["husbandry"]["habitats"] if h["facility_uid"] == r["uid"])
                definition = next(d for d in species[habitat["species_id"]]["special_diets"] if d["id"] == policy["recipe_id"])
                outputs = definition.get("outputs", species[habitat["species_id"]]["outputs"])
                deficit, per_unit = policy["target_qty"]-r["effective_before"], outputs[policy["target_item"]]
                assert policy["enabled"] and deficit > 0 and r["started"] <= (deficit+per_unit-1)//per_unit, "living target exceeded"
                for item in definition["inputs"]:
                    assert r["stock_after"].get(item, 0) >= r["reserves"].get(item, 0), "living reserve violation"
            elif kind == "water":
                key = (day, r["uid"])
                assert key not in water_changes, "duplicate water change"
                water_changes.add(key); change = catalog["husbandry"]["water"]["change"]
                assert r["inputs"] == change["inputs"] and r["outputs"] == {"wastewater": change["wastewater"]}
                assert r["after"] == min(100, r["before"]+change["gain"])
                spent[day].update(r["inputs"]); issued[day].update(r["outputs"])
            elif kind == "flower":
                key = (day, r["uid"])
                flower_use[key] += 1 if stage == "draw" else -1
                assert 0 <= flower_use[key] <= catalog["flowers"]["share_capacity"], "flower share overdraft"
                if stage != "draw": continue
                assert r["eligible"] and r["crop"] in {"honeybell_bush", "oilseed_flower"}
                if r["crop"] == "honeybell_bush": assert r["state"] == "mature"
                else: assert catalog["flowers"]["oilseed_window"][0] <= r["progress"] < catalog["flowers"]["oilseed_window"][1] and r["state"] != "mature"
                env = r["environment"]
                assert env["water"] >= catalog["flowers"]["min_water"] and env["fertility"] >= catalog["flowers"]["min_fertility"]
                assert abs(env["light"]-crops[r["crop"]]["light"]) <= catalog["flowers"]["light_tolerance"]
                flower_users[r["consumer"].split(":")[0]] += 1
                if r["consumer"] != "player":
                    assert inside(r["origin"], coverage(day, int(r["consumer"].split(":")[1]), catalog["flowers"]["range"])), "flower outside hive coverage"
                if r["pollinated"]:
                    assert r["consumer"] != "player" and r["crop"] == "oilseed_flower"
                    pollinated.add(r["uid"])
                if env["light"] > natural_light(r["origin"]) and r["consumer"] != "player":
                    assert any(d == day and inside(r["origin"], coverage(day, uid, catalog["devices"]["lamp"]["range"])) for d, uid in lamp_days), "lit flower without paid lamp"
                    lit_draws += 1
            elif kind == "harvest":
                expected = dict(crops[r["crop"]]["outputs"])
                if r["crop"] == "oilseed_flower":
                    assert r["pollinated"] == (r["uid"] in pollinated), "invented pollination"
                    expected["oilseed"] += int(r["pollinated"])
                if r["stage"] == "fell" and crops[r["crop"]]["mode"] == "tap_or_fell": expected = crops[r["crop"]]["fell_outputs"]
                assert r["outputs"] == expected, "harvest yield changed"
            elif kind == "device":
                device_use[stage] += 1
                if stage == "lamp":
                    key = (day, r["uid"])
                    assert key not in lamp_days, "duplicate lamp fuel"
                    lamp_days.add(key); fuel = catalog["devices"]["lamp"]["fuel"]
                    assert r["inputs"] == {fuel["item"]: fuel["units"]}
                    assert r["affected"] and all(a["effective"] == max(a["natural"], catalog["devices"]["lamp"]["light"]) for a in r["affected"])
                    assert all(a["natural"] == natural_light(a["origin"]) and inside(a["origin"], coverage(day, r["uid"], catalog["devices"]["lamp"]["range"])) for a in r["affected"]), "wrong lamp coverage or natural light"
                    assert any(a["natural"] < a["effective"] for a in r["affected"]), "no useful lamp effect"
                else:
                    service = catalog["devices"]["station"]["services"][stage]
                    assert inside(r["cell"], coverage(day, r["uid"], catalog["devices"]["station"]["range"])), "station outside coverage"
                    assert r["inputs"] == {service["item"]: service["units"]}
                    assert r["after"] == min(100, r["before"]+service["gain"])
                spent[day].update(r["inputs"])
        for day, entries in spent.items():
            assert all(outflows[day][i] >= q for i, q in entries.items()), (route, day, "unpaid input receipts")
        for day, entries in issued.items():
            assert all(inflows[day][i] >= q for i, q in entries.items()), (route, day, "unclaimed output receipts")
        assert dict(claims) == routes[route]["claimed"], "summary claims differ from actual receipts"
        land_receipts, land_prices, bought = defaultdict(set), Counter(), set()
        for receipt in receipts:
            if receipt['kind'] != 'expansion': continue
            ident = receipt['parcel']
            assert ident in parcels and ident not in bought, 'unknown or duplicate land purchase'
            definition = parcels[ident]
            assert set(definition['requires']) <= bought and receipt['price'] == definition['price'], 'unpaid or out-of-order land purchase'
            bought.add(ident)
            land_receipts[receipt['day']].add(ident)
            land_prices[receipt['day']] += receipt['price']
        previous = set()
        land_plantings, west_maintenance = 0, 0
        for row in days:
            day = row['day']-1
            owned = row['land']['purchased']
            assert len(owned) == len(set(owned)) and set(owned) <= parcels.keys(), 'invalid land rights'
            assert set(owned) == previous | land_receipts[day], 'land rights without a successful purchase'
            assert row['journal']['construction_spend'] >= land_prices[day], 'land price absent from cash account'
            previous = set(owned)
            def accessible(cell):
                return inside(cell, expansion['base']) or any(inside(cell,parcels[p]['rect']) for p in owned)
            for section, registry, key in [('facilities',facilities,'facility_id'), ('crops',crops,'crop_id')]:
                for instance in row[section]:
                    x,y = instance['origin']; w,h = registry[instance[key]]['footprint']
                    assert all(accessible([a,b]) for b in range(y,y+h) for a in range(x,x+w)), 'occupancy crosses locked parcel'
            land_plantings += sum(1 for crop in row['crops'] if crop['origin'] == [20,0])
            west_uids = {f['uid'] for f in row['facilities'] if f['origin'] == [-4,14] and f['facility_id'] == 'fish_pond'}
            west_maintenance += sum(1 for receipt in receipts if receipt['kind'] == 'cycle' and receipt['day'] == day and receipt['uid'] in west_uids and receipt['stage'] == 'start')
        if summary['settings'].get('expansion'):
            assert bought == parcels.keys(), 'not all parcels purchased with income'
            assert land_plantings and west_maintenance, 'new land or west reservoir never actually used'
        assert wages > 0 and reinvested, "no paid work or industry reinvestment"
        assert {items[i]["element"] for i in delivered} >= {"wood", "fire", "earth", "water", "gold"}
        assert any(processed[i] > 0 for i in ADVANCED)
        assert set(days[horizon-1]["research"]["completed"]) == projects
        final = read_json(directory / f"{route}-day{horizon}.json")
        continued = read_json(directory / f"{route}-day{horizon+1}.json")
        recap = read_json(directory / f"{route}-recap45.json")
        assert final["reports"]["recap"] == continued["reports"]["recap"] == recap
        assert final["economy"]["primeval_stones"] == days[horizon-1]["cash"]
        assert Counter(final["inventory"]) == Counter(days[horizon-1]["opening"]["closing"])
        assert final["workforce"]["spent"] == wages and payout == final["economy"]["order_revenue"]
        gaps, consumers = sorted(required-claims.keys()), sorted(required-consumed.keys())
        if require_complete:
            assert not gaps, (route, "unclaimed recipes", gaps)
            assert not consumers, (route, "products without a later real consumer", consumers)
            assert shared_days and automatic_starts and auto_steps["加工收取"], "missing shared work or automatic processing"
            assert flower_users["player"] and flower_users["hive"] and pollinated and lit_draws, "missing flower or lamp ecology"
            assert all(device_use[k] for k in ("lamp", "irrigate", "fertilize")) and water_changes, "missing device or water cycle"
        result["routes"][route] = {"day": horizon, "cash": days[horizon-1]["cash"], "wages": wages,
            "day90": {"cash": days[89]["cash"], "research": len(days[89]["research"]["completed"])},
            "research": len(projects), "recipe_claims": dict(claims), "consumers": consumed,
            "unclaimed": gaps, "unconsumed": consumers, "shared_work_days": shared_days, "automatic_starts": automatic_starts,
            "device_actions": dict(device_use), "flower_draws": dict(flower_users), "lit_flower_draws": lit_draws,
            "water_changes": len(water_changes), "failed_actions": dict(failures),
            "land": {"purchased": sorted(bought), "price": sum(land_prices.values()), "crop_days": land_plantings, "west_cycles_started": west_maintenance}}
        all_claims.update(claims); all_consumers.update(consumed)
    result["unverified_recipe_claims"] = sorted(required-all_claims)
    result["unverified_recipe_consumers"] = sorted(required-all_consumers)
    if require_complete: assert routes["A"]["research_order"] != routes["B"]["research_order"], "identical routes"
    result["auditor_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    result["evidence_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(directory.glob("*"))
        if p.is_file() and p.name not in {"audit.json", "audit-failure.json"}}
    return result

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--allow-gaps", action="store_true", help="diagnostic only; never release acceptance")
    args = parser.parse_args()
    try: result = reconcile(args.directory, not args.allow_gaps)
    except (AssertionError, KeyError, ValueError, StopIteration, OSError) as exc:
        failure = json.dumps({"mode": "failed", "error": str(exc)}, ensure_ascii=False, indent=2)+"\n"
        (args.directory / "audit-failure.json").write_text(failure, encoding="utf-8")
        (args.directory / "audit.json").write_text(failure, encoding="utf-8")
        raise SystemExit(f"P8 PLAYTEST AUDIT FAIL: {exc}") from exc
    (args.directory / "audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"P8 PLAYTEST AUDIT OK ({result['mode']}): {len(result['routes'])} x {result['settings']['days']} days; claims AND consumers reconciled")
    print("Unverified claims:", ", ".join(result["unverified_recipe_claims"]) or "none")
    print("Unverified consumers:", ", ".join(result["unverified_recipe_consumers"]) or "none")

if __name__ == "__main__": main()
