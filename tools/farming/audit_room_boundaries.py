"""Receipt audit of the small declared-room fixture; no 120-day dependency."""
import json
import sys
from pathlib import Path


def audit(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    assert data["kind"] == "boundary-module" and data["fixture"] is True
    assert not data["failures"]
    opening, closing = data["opening"], data["closing"]
    assert 0 < closing["clock"]["total_days"] - opening["clock"]["total_days"] <= 30
    fields = closing["world"]["rooms"]["fields"]
    assert len(fields) == 2 and len({r["uid"] for r in fields}) == 2
    assert not set(fields[0]["cells"]) & set(fields[1]["cells"])
    assert fields == opening["world"]["rooms"]["fields"]
    crops = {str(r["uid"]): r for r in opening["world"]["crops"]}
    owners = {c: r["name"] for r in fields for c in r["cells"]}
    growth = []
    claims = []
    for row in data["receipts"]:
        if row.get("kind") != "room":
            continue
        if row["stage"] == "growth":
            ident = row["identity"].split(":", 1)[1]
            crop = crops[ident]
            name = owners[",".join(map(str, crop["origin"]))]
            assert row["seed_qualified"] == (name == "covered")
            assert row["material_qualified"] == (name == "covered")
            state = row["state"]
            assert 0 <= state["seed_work"] <= state["growth"] <= state["target"]
            growth.append(row)
        elif row["stage"] == "claim":
            claims.append(row)
    assert growth and len(claims) == 1
    expected = {}
    for group in ("base", "seed", "material"):
        for item, count in claims[0][group].items():
            expected[item] = expected.get(item, 0) + count
    # During this fixture no purchases, feeding or crafting occur. Soil draws
    # are environmental, so all warehouse deltas must equal the one claim.
    before, after = opening["inventory"], closing["inventory"]
    for item in set(before) | set(after) | set(expected):
        assert after.get(item, 0) - before.get(item, 0) == expected.get(item, 0), item
    return {"ok": True, "days": closing["clock"]["total_days"]-opening["clock"]["total_days"],
            "growth_receipts": len(growth), "claims": len(claims), "fields": len(fields)}


if __name__ == "__main__":
    print(json.dumps(audit(sys.argv[1]), ensure_ascii=False))
