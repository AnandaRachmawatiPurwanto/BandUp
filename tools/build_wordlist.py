"""Merge the CEFR-J and Octanove CSVs into Sources/BandUpCore/Resources/words.json.

Variant spellings ("analyze/analyse") become separate entries. When a word
appears more than once (different parts of speech), every entry is kept, and
the tagger uses the lowest level for a surface form.
"""
import csv, json, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
order = ["A1", "A2", "B1", "B2", "C1", "C2"]
entries = {}
for name in ["cefrj-vocabulary-profile-1.5.csv", "octanove-vocabulary-profile-c1c2-1.0.csv"]:
    for row in csv.DictReader(open(root / "Data" / name, encoding="utf-8")):
        level = row["CEFR"].strip()
        if level not in order:
            continue
        for form in row["headword"].split("/"):
            form = form.strip()
            if not form:
                continue
            key = (form.lower(), row["pos"].strip())
            if key not in entries or order.index(level) < order.index(entries[key]["level"]):
                entries[key] = {"word": form, "pos": row["pos"].strip(), "level": level}

out = sorted(entries.values(), key=lambda e: (order.index(e["level"]), e["word"].lower()))
dest = root / "Sources" / "BandUpCore" / "Resources" / "words.json"
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
print(len(out), "entries ->", dest)
