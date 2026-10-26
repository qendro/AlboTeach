"""Compare verified SQLite snapshots before and after the card ordering migration."""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import tarfile


def asset_hashes(filename):
    with tarfile.open(filename) as archive:
        return {
            member.name: hashlib.sha256(archive.extractfile(member).read()).hexdigest()
            for member in archive.getmembers() if member.isfile()
        }


def verify(before, after):
    report = {}
    tables = before.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name!='schema_migrations'"
    ).fetchall()
    for (table,) in tables:
        columns = [row[1] for row in before.execute(f'PRAGMA table_info("{table}")')]
        fields = ','.join('"' + column + '"' for column in columns)
        query = f'SELECT {fields} FROM "{table}" ORDER BY id'
        original = before.execute(query).fetchall()
        migrated = after.execute(query).fetchall()
        assert original == migrated, f'Existing rows changed in {table}'
        report[table] = len(original)

    expected = before.execute('SELECT id FROM cards ORDER BY category,id').fetchall()
    actual = after.execute('SELECT id FROM cards ORDER BY sort_order').fetchall()
    assert actual == expected, 'Existing studio sequence changed'
    positions = after.execute('SELECT sort_order FROM cards ORDER BY sort_order').fetchall()
    assert positions == [(n,) for n in range(1, len(expected) + 1)], 'Positions are not contiguous'
    assert after.execute("SELECT count(*) FROM cards WHERE subcategory!=''").fetchone()[0] == 0
    assert after.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert after.execute('PRAGMA foreign_key_check').fetchall() == []
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before')
    parser.add_argument('after')
    parser.add_argument('--assets-before')
    parser.add_argument('--assets-after')
    parser.add_argument('--report')
    args = parser.parse_args()
    with sqlite3.connect(args.before) as before, sqlite3.connect(args.after) as after:
        report = verify(before, after)
    if args.assets_before or args.assets_after:
        assert args.assets_before and args.assets_after, 'Provide both artwork archives'
        original_assets = asset_hashes(args.assets_before)
        assert original_assets == asset_hashes(args.assets_after), 'Bundled assets changed'
        report['unchanged_assets'] = len(original_assets)
    report['integrity'] = 'ok'
    encoded = json.dumps(report, indent=2) + '\n'
    if args.report:
        Path(args.report).write_text(encoded)
    print(encoded, end='')
