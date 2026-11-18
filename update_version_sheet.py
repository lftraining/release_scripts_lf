#!/usr/bin/env python3
"""Set a course's version and date in the "Course Overview: Maintainers and versions" sheet.

Usage: update_version_sheet.py [--dry-run] [--date M/D/YYYY] COURSE VERSION [COURSE VERSION ...]

Finds each COURSE in column A of the "Version" tab and writes VERSION to
column D ("Current Version") and the date (default today) to column E ("as of").
A course not found in the sheet is reported and skipped, never added.

Uses the Google login of rclone's "remote" (the same one release_and_upload.sh
uploads with); its Google project needs the Sheets API enabled.
"""
import datetime
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SHEET_ID = "1zCsRyPDufgLK4ihgZ1x4iLZsjLaOZceDl1dA5hf1pqw"
TAB = "Version"
RCLONE_REMOTE = "remote"
API = f"https://sheets.googleapis.com/v4/spreadsheets/{SHEET_ID}"


def access_token():
    # Any rclone call refreshes an expired token and saves it to the config.
    subprocess.run(["rclone", "lsf", f"{RCLONE_REMOTE}:", "--max-depth", "1"],
                   capture_output=True, check=True)
    dump = subprocess.run(["rclone", "config", "dump"], capture_output=True,
                          text=True, check=True).stdout
    return json.loads(json.loads(dump)[RCLONE_REMOTE]["token"])["access_token"]


def call(token, url, body=None, method="GET"):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        err = json.loads(e.read() or b"{}").get("error", {})
        reasons = [d.get("reason") for d in err.get("details", [])]
        if "SERVICE_DISABLED" in reasons:
            link = next((l["url"] for d in err["details"] for l in d.get("links", [])
                         if "url" in l), None)
            sys.exit("Tip: the release script can update the version spreadsheet for you. It couldn't this "
                     "time because the Google Sheets API is turned off for the Google project behind "
                     f"rclone's '{RCLONE_REMOTE}' login.\n"
                     "Turn it on once here (signed in as that project's owner) and every future release "
                     "will update the spreadsheet automatically:\n"
                     f"  {link or 'https://console.cloud.google.com/apis/library/sheets.googleapis.com'}")
        sys.exit(f"ERROR: Google Sheets request failed ({e.code}): {err.get('message', e.reason)}")


def main(argv):
    dry_run = "--dry-run" in argv
    args = [a for a in argv if a != "--dry-run"]
    d = datetime.date.today()
    today = f"{d.month}/{d.day}/{d.year}"
    if args[:1] == ["--date"] and len(args) > 1:
        today, args = args[1], args[2:]
    if not args or len(args) % 2:
        sys.exit(__doc__)
    pairs = list(zip(args[0::2], args[1::2]))

    token = access_token()
    rng = urllib.parse.quote(f"{TAB}!A:E")
    rows = call(token, f"{API}/values/{rng}").get("values", [])
    row_of = {r[0].strip(): i + 1 for i, r in enumerate(rows) if r and r[0].strip()}

    updates, missing = [], []
    for course, version in pairs:
        n = row_of.get(course)
        if n is None:
            missing.append(course)
            continue
        old = rows[n - 1][3] if len(rows[n - 1]) > 3 else ""
        print(f"{course}: row {n}, {old or '(empty)'} -> {version} ({today})")
        # Leading ' keeps versions like 7.2 as text instead of a number; the date is still parsed.
        updates.append({"range": f"{TAB}!D{n}:E{n}", "values": [["'" + version, today]]})

    for course in missing:
        print(f"WARNING: {course} is not in the version sheet; add it by hand.", file=sys.stderr)

    if updates and not dry_run:
        call(token, f"{API}/values:batchUpdate", method="POST",
             body={"valueInputOption": "USER_ENTERED", "data": updates})
        print(f"Updated {len(updates)} row(s).")
    elif dry_run:
        print("Dry run: nothing written.")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
