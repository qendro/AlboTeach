"""SQLite collection with transactional imports, durable corrections and audit history."""

import hashlib
import json
import re
import shutil
import sqlite3
import unicodedata
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

ASSETS = Path(__file__).parent / "assets"
FIELDS = (
    "concept",
    "albanian",
    "english",
    "category",
    "part_of_speech",
    "difficulty",
    "notes",
    "source",
    "image",
)
REQUIRED = ("concept", "albanian", "english", "category")
SCHEMA = """
CREATE TABLE IF NOT EXISTS cards (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 concept TEXT NOT NULL UNIQUE,
 albanian TEXT NOT NULL, english TEXT NOT NULL, category TEXT NOT NULL,
 part_of_speech TEXT NOT NULL DEFAULT '', difficulty TEXT NOT NULL DEFAULT 'beginner',
 notes TEXT NOT NULL DEFAULT '', source TEXT NOT NULL DEFAULT '', image TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'proposed' CHECK(status IN ('proposed','approved','rejected')),
 revision INTEGER NOT NULL DEFAULT 1, reviewer TEXT, reviewed_at TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS aliases (
 kind TEXT NOT NULL, value TEXT NOT NULL, card_id INTEGER NOT NULL REFERENCES cards(id),
 UNIQUE(kind,value,card_id)
);
CREATE INDEX IF NOT EXISTS alias_lookup ON aliases(kind,value);
CREATE TABLE IF NOT EXISTS history (
 event_id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL REFERENCES cards(id),
 at TEXT NOT NULL, action TEXT NOT NULL, snapshot TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS batches (
 name TEXT PRIMARY KEY, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS batch_cards (
 batch TEXT NOT NULL REFERENCES batches(name), card_id INTEGER NOT NULL REFERENCES cards(id),
 position INTEGER NOT NULL, PRIMARY KEY(batch,card_id), UNIQUE(batch,position)
);
CREATE TABLE IF NOT EXISTS images (
 key TEXT PRIMARY KEY, path TEXT NOT NULL, credit TEXT NOT NULL, license TEXT NOT NULL, source TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


def now():
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


def norm(text):
    text = unicodedata.normalize("NFC", text).casefold()
    return " ".join("".join(c if c.isalnum() else " " for c in text).split())


def loose(text):
    return "".join(
        c
        for c in unicodedata.normalize("NFD", norm(text))
        if not unicodedata.combining(c)
    )


class Collection:
    def __init__(self, db):
        self.path = Path(db).resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._savepoint = 0
        self.conn = sqlite3.connect(self.path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys=ON")
        version = self.conn.execute("PRAGMA user_version").fetchone()[0]
        if version > 1:
            self.conn.close()
            raise ValueError(
                "Collection created by a newer application; update the tool"
            )
        self.conn.executescript(SCHEMA)
        self.conn.execute("PRAGMA user_version=1")
        self.conn.execute("INSERT OR IGNORE INTO meta VALUES ('schema_version','1')")
        manifest = json.loads((ASSETS / "images.json").read_text(encoding="utf-8"))
        for image in manifest:
            self.conn.execute(
                "INSERT OR IGNORE INTO images VALUES (?,?,?,?,?)",
                (
                    image["key"],
                    "builtin:" + image["file"],
                    image["credit"],
                    image["license"],
                    image["source"],
                ),
            )
        self.conn.commit()

    @contextmanager
    def transaction(self):
        self._savepoint += 1
        name = f"cards_tx_{self._savepoint}"
        self.conn.execute(f"SAVEPOINT {name}")
        try:
            yield
            self.conn.execute(f"RELEASE {name}")
        except Exception:
            self.conn.execute(f"ROLLBACK TO {name}")
            self.conn.execute(f"RELEASE {name}")
            raise

    def close(self):
        self.conn.close()

    def card(self, id):
        row = self.conn.execute("SELECT * FROM cards WHERE id=?", (id,)).fetchone()
        if row is None:
            raise ValueError(f"Card {id} does not exist")
        return dict(row)

    def cards(self, *, batch=None, status=None, ids=None, limit=None):
        query, params = "SELECT c.* FROM cards c", []
        if batch:
            if not self.conn.execute(
                "SELECT 1 FROM batches WHERE name=?", (batch,)
            ).fetchone():
                raise ValueError(f"Unknown batch: {batch}")
            query += " JOIN batch_cards b ON b.card_id=c.id AND b.batch=?"
            params.append(batch)
        clauses = []
        if status:
            clauses.append("c.status=?")
            params.append(status)
        if ids is not None:
            # Preserve explicit requested order and reject missing IDs.
            selected = [self.card(i) for i in ids]
            allowed = (
                {r[0] for r in self.conn.execute(query.replace("c.*", "c.id"), [batch])}
                if batch
                else None
            )
            if allowed is not None and any(c["id"] not in allowed for c in selected):
                raise ValueError("Requested card is outside the batch")
            return [c for c in selected if not status or c["status"] == status][:limit]
        if clauses:
            query += " WHERE " + " AND ".join(clauses)
        query += " ORDER BY " + ("b.position" if batch else "c.id")
        if limit is not None:
            query += " LIMIT ?"
            params.append(limit)
        return [dict(r) for r in self.conn.execute(query, params)]

    def image(self, key):
        if not key:
            return None
        row = self.conn.execute("SELECT * FROM images WHERE key=?", (key,)).fetchone()
        if row is None:
            raise ValueError(f"Unknown image {key!r}; use 'images' or 'image-add'")
        item = dict(row)
        item["resolved_path"] = (
            str(ASSETS / "images" / item["path"][8:])
            if item["path"].startswith("builtin:")
            else str(self.path.parent / item["path"])
        )
        if not Path(item["resolved_path"]).is_file():
            raise ValueError(f"Missing image: {item['resolved_path']}")
        return item

    def validate(self, content):
        unknown = set(content) - set(FIELDS)
        if unknown:
            raise ValueError(f"Unknown content fields: {', '.join(sorted(unknown))}")
        out = {
            f: content.get(f, "beginner" if f == "difficulty" else "") for f in FIELDS
        }
        for f, v in out.items():
            if not isinstance(v, str):
                raise ValueError(f"{f} must be text")
            v = unicodedata.normalize("NFC", v).strip()
            if any(
                unicodedata.category(c).startswith("C") and c not in "\n\t" for c in v
            ):
                raise ValueError(f"{f} contains unsupported control characters")
            if len(v) > (2000 if f in ("notes", "source") else 300):
                raise ValueError(f"{f} is too long")
            out[f] = v
        for f in REQUIRED:
            if not out[f] or not norm(out[f]):
                raise ValueError(f"{f} must not be blank")
        if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,99}", out["concept"]):
            raise ValueError("concept must be a stable lowercase key, e.g. food.apple")
        self.image(out["image"])
        return out

    def duplicate(self, content, exclude=None):
        found = []
        for kind, key in [
            ("concept", content["concept"]),
            ("albanian", norm(content["albanian"])),
            ("english", norm(content["english"])),
        ]:
            for r in self.conn.execute(
                "SELECT card_id FROM aliases WHERE kind=? AND value=?", (kind, key)
            ):
                if r[0] != exclude:
                    found.append({"id": r[0], "matched": kind})
        return found

    def remember(self, card):
        for kind, value in [
            ("concept", card["concept"]),
            ("albanian", norm(card["albanian"])),
            ("english", norm(card["english"])),
        ]:
            self.conn.execute(
                "INSERT OR IGNORE INTO aliases VALUES (?,?,?)",
                (kind, value, card["id"]),
            )

    def event(self, id, action):
        self.conn.execute(
            "INSERT INTO history(card_id,at,action,snapshot) VALUES (?,?,?,?)",
            (id, now(), action, json.dumps(self.card(id), ensure_ascii=False)),
        )

    def import_batch(self, document, batch):
        if not batch.strip():
            raise ValueError("Batch name must not be empty")
        items = document.get("cards") if isinstance(document, dict) else document
        if not isinstance(items, list) or not items:
            raise ValueError("Expected a nonempty JSON array or {cards: [...]}")
        # Validate everything before beginning changes, then import atomically.
        cleaned = [
            self.validate(c) if isinstance(c, dict) else self.validate({})
            for c in items
        ]
        result = {"batch": batch, "added": [], "duplicates": []}
        with self.transaction():
            if self.conn.execute(
                "SELECT 1 FROM batches WHERE name=?", (batch,)
            ).fetchone():
                raise ValueError(
                    "Batch already exists; use a new name (collections are immutable)"
                )
            self.conn.execute("INSERT INTO batches VALUES (?,?)", (batch, now()))
            for content in cleaned:
                matches = self.duplicate(content)
                if matches:
                    result["duplicates"].append(
                        {"concept": content["concept"], "matches": matches}
                    )
                    continue
                stamp = now()
                q = (
                    "INSERT INTO cards("
                    + ",".join(FIELDS)
                    + ",created_at,updated_at) VALUES ("
                    + ",".join("?" for _ in range(len(FIELDS) + 2))
                    + ")"
                )
                id = self.conn.execute(
                    q, (*[content[f] for f in FIELDS], stamp, stamp)
                ).lastrowid
                self.conn.execute(
                    "INSERT INTO batch_cards VALUES (?,?,?)",
                    (batch, id, len(result["added"])),
                )
                self.remember(self.card(id))
                self.event(id, "proposed")
                result["added"].append(id)
        return result

    def update(self, id, patch, expected_revision=None):
        with self.transaction():
            c = self.card(id)
            if expected_revision is not None and expected_revision != c["revision"]:
                raise ValueError(
                    "Revision conflict; read the current card before editing"
                )
            merged = self.validate({**{f: c[f] for f in FIELDS}, **patch})
            if self.duplicate(merged, exclude=id):
                raise ValueError(
                    "Correction collides with another card or its historical wording"
                )
            if all(c[f] == merged[f] for f in FIELDS):
                return c
            self.remember(c)
            self.conn.execute(
                "UPDATE cards SET "
                + ",".join(f + "=?" for f in FIELDS)
                + ", status='proposed',reviewer=NULL,reviewed_at=NULL,revision=revision+1,updated_at=? WHERE id=?",
                (*[merged[f] for f in FIELDS], now(), id),
            )
            self.remember(self.card(id))
            self.event(id, "corrected; approval cleared")
        return self.card(id)

    def review(self, ids, status, reviewer, expected=None):
        if status not in ("approved", "rejected") or not reviewer.strip():
            raise ValueError("Explicit reviewer and approved/rejected status required")
        if not ids:
            raise ValueError("No cards selected")
        with self.transaction():
            for id in ids:
                c = self.card(id)
                if expected and expected.get(id) != c["revision"]:
                    raise ValueError(
                        f"Card {id} changed since review export; export a fresh review"
                    )
                self.image(c["image"])
                self.conn.execute(
                    "UPDATE cards SET status=?,reviewer=?,reviewed_at=?,updated_at=? WHERE id=?",
                    (status, reviewer, now(), now(), id),
                )
                self.event(id, status)
        return [self.card(i) for i in ids]

    def add_image(self, key, path, credit, license, source):
        from PIL import Image

        if not all(x.strip() for x in (key, credit, license, source)):
            raise ValueError("Image key, credit, license and source are required")
        if self.conn.execute("SELECT 1 FROM images WHERE key=?", (key,)).fetchone():
            raise ValueError(
                "Image keys are immutable; choose a new key for a replacement"
            )
        with Image.open(path) as img:
            img.load()
            if img.format not in ("PNG", "JPEG"):
                raise ValueError("Import PNG or JPEG images")
            suffix = ".png" if img.format == "PNG" else ".jpg"
        data = Path(path).read_bytes()
        name = hashlib.sha256(data).hexdigest() + suffix
        dest = self.path.parent / "media" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            dest.write_bytes(data)
        with self.transaction():
            self.conn.execute(
                "INSERT INTO images VALUES (?,?,?,?,?)",
                (key, "media/" + name, credit, license, source),
            )
        return key

    def backup(self, target):
        target = Path(target).resolve()
        if target == self.path or target.exists():
            raise ValueError("Choose a new backup directory")
        target.mkdir(parents=True)
        with sqlite3.connect(target / self.path.name) as dest:
            self.conn.backup(dest)
        if (self.path.parent / "media").exists():
            shutil.copytree(self.path.parent / "media", target / "media")
        return str(target)

    def brief(self, count, topic):
        aliases = {
            kind: [
                r[0]
                for r in self.conn.execute(
                    "SELECT DISTINCT value FROM aliases WHERE kind=? ORDER BY value",
                    (kind,),
                )
            ]
            for kind in ("concept", "albanian", "english")
        }
        return {
            "task": f"Propose {count} new beginner Kosovo Albanian flashcards about {topic}",
            "rules": [
                "Return JSON with a cards array using the template fields.",
                "Parent/tutor-approved wording is the primary dialect authority.",
                "Every import is proposed; AI confidence is never approval.",
                "Avoid all excluded concepts and old spellings/translations; do not silently alter approved cards.",
                "Prefer one word or a short natural expression; mark dialect uncertainty in notes.",
                "Use empty image for abstract expressions. Images must clearly represent the intended sense.",
                "Use stable English concept keys to group inflections/synonyms; manual semantic review remains necessary.",
            ],
            "template": dict(
                zip(
                    FIELDS,
                    [
                        "food.apple",
                        "mollë",
                        "apple",
                        "food",
                        "noun",
                        "beginner",
                        "AI draft; tutor review required",
                        "AI proposal",
                        "apple",
                    ],
                )
            ),
            "approved_wording": [
                {k: c[k] for k in ("id", "concept", "albanian", "english", "notes")}
                for c in self.cards(status="approved")
            ],
            "excluded": aliases,
            "available_images": [
                r[0] for r in self.conn.execute("SELECT key FROM images ORDER BY key")
            ],
        }
