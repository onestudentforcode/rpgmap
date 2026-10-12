"""Corrupt copies of a completed real run; each audit gate must reject its probe."""
import argparse
import copy
import json
from pathlib import Path
import shutil

from audit_p8_playtest import reconcile, read_json, read_lines


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_lines(path, rows):
    for number, row in enumerate(rows, 1):
        if "sequence" in row:
            row["sequence"] = number
    path.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--probe-root", type=Path, default=Path(".art-work/p8h-audit-negative"))
    args = parser.parse_args()
    reconcile(args.directory)  # refuse a baseline that already fails
    results = {}
    names = ("cash", "stock", "wages", "claim_duplicate", "flower_overdraft",
             "water_duplicate", "reserve", "missing_recipe", "device_gain", "false_consumer")
    for name in names:
        folder = args.probe_root / name
        folder.mkdir(parents=True, exist_ok=True)
        for file in args.directory.iterdir():
            if file.is_file() and file.name not in {"audit.json", "audit-failure.json"}:
                shutil.copy2(file, folder / file.name)
        days = read_lines(folder / "A-days.jsonl")
        receipts = read_lines(folder / "A-receipts.jsonl")
        if name == "cash":
            days[0]["cash"] += 1
        elif name == "stock":
            days[0]["ledger"]["closing"]["grain"] = days[0]["ledger"]["closing"].get("grain", 0) + 1
        elif name == "wages":
            next(day for day in days if day["workers"]["workers"])["workers"]["workers"][0]["fee"] += 1
        elif name in {"claim_duplicate", "flower_overdraft", "water_duplicate"}:
            target = next(r for r in receipts if (name == "claim_duplicate" and r["kind"] == "batch" and r["stage"] == "claim")
                          or (name == "flower_overdraft" and r["kind"] == "flower" and r["stage"] == "draw")
                          or (name == "water_duplicate" and r["kind"] == "water"))
            receipts.append(copy.deepcopy(target))
        elif name == "reserve":
            target = next(r for r in receipts if r["kind"] == "batch" and r["stage"] == "start" and r["operator"] == "worker")
            item = next(iter(target["inputs"]))
            target["stock_before"][item] = target["inputs"][item] + target["reserves"].get(item, 0) - 1
        elif name == "missing_recipe":
            rid = "honey_mineral_food"
            receipts = [r for r in receipts if not (r["kind"] == "batch" and r["stage"] == "claim" and r["recipe"] == rid)]
            summary = read_json(folder / "summary.json")
            del summary["routes"]["A"]["claimed"][rid]
            write(folder / "summary.json", summary)
        elif name == "device_gain":
            next(r for r in receipts if r["kind"] == "device" and r["stage"] == "irrigate")["after"] += 1
        elif name == "false_consumer":
            target = next(day["ledger"]["outflows"]["gold_food"] for day in days if "gold_food" in day["ledger"]["outflows"])
            total = sum(target.values())
            target.clear()
            target["开发丢弃"] = total  # balanced stock cannot masquerade as a legitimate consumer
        write_lines(folder / "A-days.jsonl", days)
        write_lines(folder / "A-receipts.jsonl", receipts)
        try:
            reconcile(folder)
        except (AssertionError, KeyError, ValueError, StopIteration) as exc:
            results[name] = {"rejected": True, "reason": str(exc)}
        else:
            raise SystemExit(f"AUDIT NEGATIVE PROBE FAIL: accepted {name}")
    write(args.probe_root / "expected-rejections.json", results)
    print(f"P8 AUDIT NEGATIVE PROBES OK: {len(results)} corruptions rejected")


if __name__ == "__main__":
    main()
