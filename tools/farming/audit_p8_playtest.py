"""Reconcile exported real-play days without relying on the frozen 45-day recap."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INCOME = ("sales_revenue", "order_revenue")
EXPENSE = ("purchase_spend", "construction_spend", "labour_spend")
ADVANCED = {"dew_soup", "fire_paste", "earth_pill", "gold_food"}


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def reconcile(directory: Path) -> dict:
    summary = read_json(directory / "summary.json")
    assert not summary["failures"], summary["failures"]
    manifest = read_json(directory / "manifest.json")
    for name, digest in manifest.items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    catalog = read_json(ROOT / "content/farming/baked/p8/production.json")
    assert catalog["config"]["ap_per_day"] == 24 and catalog["config"]["initial_primeval_stones"] == 60
    items = {row["id"]: row for row in catalog["resources"]}
    expected_projects = {row["id"] for row in catalog["research"]}
    species = {row["id"]: row for row in catalog["livestock"]}
    required_recipes = {row["id"] for row in catalog["recipes"] if row.get("research")}
    result = {}
    combined_claims = Counter()
    for route in "AB":
        days = [json.loads(line) for line in (directory / f"{route}-days.jsonl").read_text(encoding="utf-8").splitlines()]
        assert [row["day"] for row in days] == list(range(1, 92)), route
        cash = 60
        delivered = Counter()
        processed = Counter()
        claims = Counter()
        labour = 0
        inventory = None
        assert days[0]["ledger"]["opening"] == catalog["config"]["start_inventory"]
        for row in days:
            for habitat in row["husbandry"]["habitats"]:
                gate = species[habitat["species_id"]].get("research")
                assert not habitat["individuals"] or not gate or gate in row["research"]["completed"], (route, row["day"], "locked species")
            ledger = row["ledger"]
            assert ledger["day"] == row["day"] - 1
            stock = Counter(ledger["opening"])
            if inventory is not None:
                assert stock == inventory, (route, row["day"], "stock continuity")
            for item, reasons in ledger["inflows"].items():
                assert not any("开发" in reason or "脚手架" in reason for reason in reasons), (route, "injected resources")
                assert all(isinstance(value, (int, float)) and value > 0 and value == int(value) for value in reasons.values())
                stock[item] += sum(reasons.values())
            for item, reasons in ledger["outflows"].items():
                assert all(value > 0 and value == int(value) for value in reasons.values())
                stock[item] -= sum(reasons.values())
            assert all(value >= 0 for value in stock.values()), (route, row["day"], "negative stock")
            inventory = Counter(ledger["closing"])
            assert stock == inventory, (route, row["day"], "stock balance")
            journal = row["journal"]
            cash += sum(journal[key] for key in INCOME) - sum(journal[key] for key in EXPENSE)
            assert cash == row["cash"], (route, row["day"], "cash balance")
            workers = row["workers"]["workers"]
            assert journal["labour_spend"] == sum(w["fee"] for w in workers) == sum(w["success"] for w in workers)
            if row["day"] <= 90:
                labour += journal["labour_spend"]
                delivered.update(journal["delivered_items"])
                processed.update(journal["processed"])
                for report in row["report"]["history"]:
                    if report["day"] != row["day"] - 1:
                        continue
                    for event in report["entries"]:
                        if event["category"] != "claim":
                            continue
                        heads = event["count"]
                        for recipe in catalog["recipes"]:
                            if recipe.get("living") and event["items"] == {item: qty * heads for item, qty in recipe["outputs"].items()}:
                                claims[recipe["id"]] += heads
        actions = [json.loads(line) for line in (directory / f"{route}-actions.jsonl").read_text(encoding="utf-8").splitlines()]
        failed = Counter()
        orders = set()
        order_payout = 0
        first_new_income = None
        reinvested = False
        for action in actions:
            assert 0 <= action["ap_before"] <= 24 and 0 <= action["ap_after"] <= 24
            receipt = action["result"]
            if not receipt.get("ok", True):
                failed[receipt.get("reason", "unknown")] += 1
            if receipt.get("ok") and action["action"].startswith("world.claim_batch"):
                claims[action["claimed_recipe"]] += 1
            if receipt.get("ok") and "order_id" in receipt:
                assert receipt["order_id"] not in orders, (route, "duplicate order settlement")
                orders.add(receipt["order_id"])
                order_payout += receipt["quote"]["payout"]
                if receipt["quote"]["item_id"] in {"honey", "refined_oil", "nectar", *ADVANCED}:
                    first_new_income = action["day"] if first_new_income is None else first_new_income
            if first_new_income is not None and action["day"] > first_new_income and receipt.get("ok") \
                    and receipt.get("item_id") in {"raw_wood", "twig", "golden_wheat_seed", "grass_seed", "wood_decay_spawn"} \
                    and "buy" in action["action"]:
                reinvested = True
        assert not any("行动点不足" in reason for reason in failed), (route, failed)
        # This is a coverage gap report, not a claim that all P8.h gates pass.
        assert labour > 0
        assert reinvested, (route, "new industry income followed by production purchases")
        assert {items[item]["element"] for item in delivered} >= {"wood", "fire", "earth", "water", "gold"}
        assert any(processed[item] > 0 for item in ADVANCED)
        assert set(days[89]["research"]["completed"]) == expected_projects
        final = read_json(directory / f"{route}-day90.json")
        continued = read_json(directory / f"{route}-day91.json")
        recap = read_json(directory / f"{route}-recap45.json")
        assert final["reports"]["recap"] == continued["reports"]["recap"] == recap
        assert final["economy"]["primeval_stones"] == days[89]["cash"]
        assert final["inventory"] == days[89]["ledger"]["closing"]
        assert final["workforce"]["spent"] == labour
        assert order_payout == final["economy"]["order_revenue"]
        result[route] = {"day": 90, "cash": days[89]["cash"], "wages": labour,
                         "research": len(expected_projects), "processed": dict(processed),
                         "delivered_items": dict(delivered), "recipe_claims": dict(claims),
                         "failed_actions": dict(failed)}
        combined_claims.update(claims)
    result["unverified_recipe_claims"] = sorted(required_recipes - combined_claims.keys())
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    result = reconcile(args.directory)
    (args.directory / "audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("P8 PLAYTEST AUDIT OK: 2 x 90 days + day 91; inventory, cash, wages and recap reconciled")
    print("Unverified recipe claims:", ", ".join(result["unverified_recipe_claims"]) or "none")


if __name__ == "__main__":
    main()
