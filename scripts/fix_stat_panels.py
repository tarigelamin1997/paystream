import json

f = "/etc/grafana/paystream/dashboards/04_pipeline_slos.json"
with open(f) as fh:
    d = json.load(fh)

# Check for and fix duplicate panels
seen_titles = set()
deduped = []
for panel in d.get("panels", []):
    title = panel.get("title", "")
    if title in seen_titles:
        print("Removing duplicate: " + title)
        continue
    seen_titles.add(title)
    
    # For stat panels, ensure no time range filtering
    if panel.get("type") == "stat":
        panel["timeFrom"] = None
        panel["timeShift"] = None
        print("Set timeFrom=null on stat: " + title)
    
    deduped.append(panel)

d["panels"] = deduped
with open(f, "w") as fh:
    json.dump(d, fh, indent=2)
print("Saved. Panels: " + str(len(deduped)))
