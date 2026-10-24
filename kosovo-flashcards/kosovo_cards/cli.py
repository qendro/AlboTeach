"""Small JSON-speaking CLI intended to be operated by Codex."""

import argparse
import csv
import json
import sqlite3
import sys
from pathlib import Path
from .store import Collection, FIELDS, loose


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(value, path=None):
    text = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    if path:
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    else:
        print(text, end="")


def parse_ids(text):
    result = []
    for bit in text.split(","):
        if "-" in bit:
            a, b = map(int, bit.split("-", 1))
            if a <= 0 or b < a or b - a > 10000:
                raise ValueError("Invalid ID range")
            result.extend(range(a, b + 1))
        else:
            result.append(int(bit))
    if any(i <= 0 for i in result):
        raise ValueError("IDs must be positive")
    return list(dict.fromkeys(result))


def add_selection(p):
    p.add_argument("--batch")
    p.add_argument("--ids", type=parse_ids)
    p.add_argument("--status", choices=["proposed", "approved", "rejected"])
    p.add_argument("--limit", type=int)


def selected(store, args):
    if args.limit is not None and args.limit < 1:
        raise ValueError("Limit must be positive")
    return store.cards(
        batch=args.batch, ids=args.ids, status=args.status, limit=args.limit
    )


def make_parser():
    p = argparse.ArgumentParser(
        description="Local Kosovo Albanian flashcards; use Codex to propose content."
    )
    p.add_argument(
        "--db",
        default="data/cards.sqlite",
        help="Collection path (default: data/cards.sqlite)",
    )
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("init", help="Create or open a collection")
    q = sub.add_parser(
        "import", help="Import draft JSON; never overwrite existing cards"
    )
    q.add_argument("file")
    q.add_argument("--batch", required=True)
    q = sub.add_parser("list")
    add_selection(q)
    q = sub.add_parser("show")
    q.add_argument("id", type=int)
    q = sub.add_parser("history")
    q.add_argument("id", type=int)
    q = sub.add_parser("update", help="Apply a content patch; clears approval")
    q.add_argument("id", type=int)
    q.add_argument(
        "--patch", required=True, help="JSON file with changed content fields"
    )
    q.add_argument("--revision", type=int, required=True)
    q = sub.add_parser(
        "brief",
        help="Export generation instructions and existing-word exclusions for Codex",
    )
    q.add_argument("--count", type=int, required=True)
    q.add_argument("--topic", required=True)
    q.add_argument("-o", "--output", required=True)
    q = sub.add_parser(
        "review", help="Export editable review JSON and/or a static visual HTML report"
    )
    add_selection(q)
    q.add_argument("--json")
    q.add_argument("--html")
    q = sub.add_parser(
        "apply-review",
        help="Apply deliberate decisions from reviewed JSON, with revision checks",
    )
    q.add_argument("file")
    q.add_argument("--reviewer", required=True)
    q = sub.add_parser(
        "approve", help="Record explicit parent/tutor approval of selected cards"
    )
    q.add_argument("--ids", type=parse_ids, required=True)
    q.add_argument("--reviewer", required=True)
    q = sub.add_parser("reject")
    q.add_argument("--ids", type=parse_ids, required=True)
    q.add_argument("--reviewer", required=True)
    q = sub.add_parser(
        "render",
        help="Print selected cards; proposed content requires --allow-proposed",
    )
    add_selection(q)
    q.add_argument("-o", "--output", required=True)
    q.add_argument("--allow-proposed", action="store_true")
    q.add_argument("--per-sheet", type=int, choices=[8, 10], default=8)
    q.add_argument("--flip", choices=["long-edge", "short-edge"], default="long-edge")
    q.add_argument("--back-x-mm", type=float, default=0)
    q.add_argument("--back-y-mm", type=float, default=0)
    q = sub.add_parser(
        "calibration", help="Generate one numbered duplex test sheet (no vocabulary)"
    )
    q.add_argument("-o", "--output", required=True)
    q.add_argument("--flip", choices=["long-edge", "short-edge"], default="long-edge")
    q.add_argument("--back-x-mm", type=float, default=0)
    q.add_argument("--back-y-mm", type=float, default=0)
    sub.add_parser("images")
    q = sub.add_parser(
        "image-add", help="Copy an image into managed media with its credit"
    )
    q.add_argument("file")
    q.add_argument("--key", required=True)
    q.add_argument("--credit", required=True)
    q.add_argument("--license", required=True)
    q.add_argument("--source", required=True)
    q = sub.add_parser("export", help="Export current vocabulary as UTF-8 JSON or CSV")
    add_selection(q)
    q.add_argument("-o", "--output", required=True)
    q = sub.add_parser(
        "duplicates", help="Show possible accent/spelling variants for human review"
    )
    q = sub.add_parser(
        "backup", help="Consistent SQLite backup, including managed media"
    )
    q.add_argument("directory")
    return p


def apply_review(store, document, reviewer):
    if (
        not isinstance(document, dict)
        or document.get("schema_version") != 1
        or not isinstance(document.get("cards"), list)
    ):
        raise ValueError("Expected review export with schema_version 1 and cards")
    rows = document["cards"]
    seen = set()
    prepared = []
    # Validate entire review before changing any card.
    for row in rows:
        if set(row) - {"id", "revision", "decision", *FIELDS}:
            raise ValueError("Unknown review fields")
        id = row["id"]
        current = store.card(id)
        if id in seen:
            raise ValueError("Duplicate card ID in review file")
        seen.add(id)
        if current["revision"] != row["revision"]:
            raise ValueError(f"Card {id} changed since review export")
        decision = row.get("decision", "")
        if decision not in ("", "approved", "rejected"):
            raise ValueError("Decision must be blank, approved, or rejected")
        content = store.validate({f: row[f] for f in FIELDS})
        prepared.append((id, content, decision, row["revision"]))
    with store.transaction():
        for id, content, decision, revision in prepared:
            updated = store.update(id, content, expected_revision=revision)
            if decision:
                store.review(
                    [id], decision, reviewer, expected={id: updated["revision"]}
                )
    return {
        "reviewed": len(rows),
        "approved": sum(d == "approved" for _, _, d, _ in prepared),
    }


def run(args):
    store = Collection(args.db)
    try:
        cmd = args.command
        if cmd == "init":
            return {
                "database": str(store.path),
                "cards": len(store.cards()),
                "schema_version": 1,
            }
        if cmd == "import":
            return store.import_batch(read_json(args.file), args.batch)
        if cmd == "list":
            return selected(store, args)
        if cmd == "show":
            return store.card(args.id)
        if cmd == "history":
            store.card(args.id)
            return [
                {**dict(r), "snapshot": json.loads(r["snapshot"])}
                for r in store.conn.execute(
                    "SELECT * FROM history WHERE card_id=? ORDER BY event_id",
                    (args.id,),
                )
            ]
        if cmd == "update":
            return store.update(args.id, read_json(args.patch), args.revision)
        if cmd == "brief":
            if not 1 <= args.count <= 1000:
                raise ValueError("Count must be between 1 and 1000")
            write_json(store.brief(args.count, args.topic), args.output)
            return {"brief": args.output}
        if cmd == "review":
            cards = selected(store, args)
            if not args.json and not args.html:
                raise ValueError("Choose --json, --html, or both")
            if args.json:
                write_json(
                    {
                        "schema_version": 1,
                        "cards": [
                            {
                                **{k: c[k] for k in ("id", "revision", *FIELDS)},
                                "decision": "",
                            }
                            for c in cards
                        ],
                    },
                    args.json,
                )
            if args.html:
                from .printing import review_html

                review_html(store, cards, args.html)
            return {
                "cards": len(cards),
                "review_json": args.json,
                "visual_review": args.html,
            }
        if cmd == "apply-review":
            return apply_review(store, read_json(args.file), args.reviewer)
        if cmd in ("approve", "reject"):
            return store.review(
                args.ids, "approved" if cmd == "approve" else "rejected", args.reviewer
            )
        if cmd == "render":
            from .printing import render_pdf

            return render_pdf(
                store,
                selected(store, args),
                args.output,
                per_sheet=args.per_sheet,
                flip=args.flip,
                allow_proposed=args.allow_proposed,
                back_x_mm=args.back_x_mm,
                back_y_mm=args.back_y_mm,
            )
        if cmd == "calibration":
            from .printing import calibration

            return calibration(args.output, args.flip, args.back_x_mm, args.back_y_mm)
        if cmd == "images":
            return [
                dict(r) for r in store.conn.execute("SELECT * FROM images ORDER BY key")
            ]
        if cmd == "image-add":
            return {
                "image": store.add_image(
                    args.key, args.file, args.credit, args.license, args.source
                )
            }
        if cmd == "export":
            cards = selected(store, args)
            p = Path(args.output)
            p.parent.mkdir(parents=True, exist_ok=True)
            if p.suffix.casefold() == ".csv":
                with p.open("w", newline="", encoding="utf-8") as f:
                    w = csv.DictWriter(
                        f,
                        fieldnames=[
                            "id",
                            *FIELDS,
                            "status",
                            "revision",
                            "reviewer",
                            "reviewed_at",
                            "created_at",
                            "updated_at",
                        ],
                    )
                    w.writeheader()
                    w.writerows(cards)
            else:
                write_json({"schema_version": 1, "cards": cards}, p)
            return {"export": str(p), "cards": len(cards)}
        if cmd == "duplicates":
            groups = {}
            for row in store.conn.execute(
                "SELECT value,card_id FROM aliases WHERE kind='albanian'"
            ):
                groups.setdefault(loose(row["value"]), set()).add(row["card_id"])
            return [
                {"comparison": k, "ids": sorted(v)}
                for k, v in groups.items()
                if len(v) > 1
            ]
        if cmd == "backup":
            return {"backup": store.backup(args.directory)}
        raise ValueError("Unknown command")
    finally:
        store.close()


def main():
    parser = make_parser()
    args = parser.parse_args()
    try:
        write_json(run(args))
    except (ValueError, KeyError, TypeError, OSError, sqlite3.Error) as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
