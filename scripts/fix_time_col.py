import json, glob, os, re

fixed = 0
for f in sorted(glob.glob("/etc/grafana/paystream/dashboards/*.json")):
    with open(f) as fh:
        d = json.load(fh)
    fname = os.path.basename(f)
    changed = False
    for panel in d.get("panels", []):
        if panel.get("type") != "stat":
            continue
        title = panel.get("title", "")
        for target in panel.get("targets", []):
            sql = target.get("rawSql", "")
            if not sql.strip():
                continue
            # Check if query already has a time column
            lower = sql.lower()
            if "as time" in lower or "now() as time" in lower:
                continue
            # Add now() AS time after SELECT
            if lower.strip().startswith("select"):
                new_sql = sql.strip()[:6] + " now() AS time," + sql.strip()[6:]
                target["rawSql"] = new_sql
                changed = True
                fixed += 1
                print("FIXED: " + fname + " / " + title)
    if changed:
        with open(f, "w") as fh:
            json.dump(d, fh, indent=2)

print(str(fixed) + " stat panels updated")
