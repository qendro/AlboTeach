"""A reproducible end-to-end software fixture. Does not approve real vocabulary."""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / "output" / "workflow-demo"
if DEMO.exists():
    sys.exit(
        "Demo directory already exists; preserve it or choose another output location before rerunning."
    )
DEMO.mkdir(parents=True)


def run(*args):
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "kosovo_cards",
            "--db",
            str(DEMO / "cards.sqlite"),
            *args,
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    print(result.stdout.strip())
    return json.loads(result.stdout)


# Deliberately synthetic language, clearly distinct from the real starter cards.
source = DEMO / "draft.json"
source.write_text(
    json.dumps(
        {
            "cards": [
                {
                    "concept": f"software.test_{i}",
                    "albanian": f"TEST FRONT {i}",
                    "english": f"TEST BACK {i}",
                    "category": "software fixture",
                    "notes": "Synthetic software test. Not Albanian vocabulary or linguistic verification.",
                    "source": "Software fixture",
                    "image": "apple" if i == 1 else "",
                }
                for i in range(1, 4)
            ]
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
run("import", str(source), "--batch", "software-fixture")
run(
    "review",
    "--batch",
    "software-fixture",
    "--json",
    str(DEMO / "review.json"),
    "--html",
    str(DEMO / "before-review.html"),
)
review = json.loads((DEMO / "review.json").read_text())
review["cards"][0]["notes"] += " Reviewed for software behavior only."
for card in review["cards"]:
    card["decision"] = "approved"
(DEMO / "review.json").write_text(json.dumps(review, indent=2) + "\n", encoding="utf-8")
run(
    "apply-review",
    str(DEMO / "review.json"),
    "--reviewer",
    "SOFTWARE FIXTURE ONLY - not linguistic approval",
)
run("render", "--batch", "software-fixture", "-o", str(DEMO / "approved-fixture.pdf"))
run("export", "-o", str(DEMO / "saved-approved.json"))
print("The real starter collection was left untouched.")
