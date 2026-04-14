#!/usr/bin/env python3
"""
migrate_tees.py — Phase 2 migration for multi-tee support.

Reads cached GolfCourseAPI responses from tools/api_cache/*.json and enriches
TeeMetrics/Resources/courses.json with a new top-level "tees" array on each
course. Existing top-level par/yardage/slope/rating/holes fields are left
intact for backward compatibility.

Usage (from repo root):
    python3 tools/migrate_tees.py

Environment:
    No network calls. No API key needed. Reads only from tools/api_cache/.

Inputs:
    tools/api_cache_index.json              — {course_name: course_id}
    tools/api_cache/<course_id>.json        — full API response per course
    TeeMetrics/Resources/courses.json       — existing course data to enrich

Output:
    TeeMetrics/Resources/courses.json       — updated in place with "tees" arrays
    TeeMetrics/Resources/courses.json.tees.bak — timestamped backup before edit

Cached API response structure (per course):
    {
      "id": 6219,
      "club_name": "...",
      "course_name": "...",
      "location": {"latitude": ..., "longitude": ...},
      "tees": {
        "male": [
          {
            "tee_name": "Blue",
            "course_rating": 73.5,
            "slope_rating": 138,
            "total_yards": 6832,
            "par_total": 72,
            "holes": [{"par": 4, "yardage": 426, "handicap": 5}, ...]
          },
          ...
        ],
        "female": [...]
      }
    }

Output tee structure (in courses.json):
    "tees": [
      {
        "name": "Blue",
        "gender": "male",
        "par": 72,
        "yardage": 6832,
        "slope": 138,
        "rating": 73.5,
        "holes": [{"num": 1, "par": 4, "yds": 426, "hcp": 5}, ...]
      },
      ...
    ]

Unmatched courses (not in the cache index) get "tees": [] and are left
otherwise untouched. The Swift side handles empty tees by hiding the tee
picker and falling back to the existing default scorecard.
"""

from __future__ import annotations

import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

# --- Paths (relative to repo root) ----------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = REPO_ROOT / "tools" / "api_cache"
INDEX_PATH = REPO_ROOT / "tools" / "api_cache_index.json"
COURSES_PATH = REPO_ROOT / "TeeMetrics" / "TeeMetrics" / "Resources" / "courses.json"


def die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_json(path: Path):
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        die(f"Missing file: {path}")
    except json.JSONDecodeError as e:
        die(f"Invalid JSON in {path}: {e}")


def normalize_name(name: str) -> str:
    """Case-insensitive, whitespace-collapsed key for index lookups."""
    return " ".join(name.lower().split())


def transform_tee(tee_dict: dict, gender: str) -> dict | None:
    """Convert one cached API tee into our courses.json tee shape.

    Returns None if the cached tee lacks required fields.
    """
    try:
        name = tee_dict.get("tee_name") or "Unknown"
        par = int(tee_dict.get("par_total") or 0)
        yardage = int(tee_dict.get("total_yards") or 0)
        slope = int(tee_dict.get("slope_rating") or 0)
        rating = float(tee_dict.get("course_rating") or 0.0)
        raw_holes = tee_dict.get("holes") or []
    except (TypeError, ValueError):
        return None

    # Require at least a usable par and at least 1 hole
    if par <= 0 or not raw_holes:
        return None

    holes: list[dict] = []
    for i, h in enumerate(raw_holes, start=1):
        try:
            hpar = int(h.get("par") or 0)
            yds = int(h.get("yardage") or 0)
            hcp = int(h.get("handicap") or (i % 18 + 1))
        except (TypeError, ValueError):
            continue
        if hpar <= 0:
            continue
        holes.append({"num": i, "par": hpar, "yds": yds, "hcp": hcp})

    # Require full 18 holes; partial data is dropped
    if len(holes) != 18:
        return None

    return {
        "name": name,
        "gender": gender,
        "par": par,
        "yardage": yardage,
        "slope": slope,
        "rating": rating,
        "holes": holes,
    }


def extract_tees(cached: dict) -> list[dict]:
    """Flatten cached tees.male + tees.female into a single tagged array."""
    result: list[dict] = []
    tees_obj = cached.get("tees") or {}

    male_tees = tees_obj.get("male") or []
    for t in male_tees:
        shaped = transform_tee(t, gender="male")
        if shaped is not None:
            result.append(shaped)

    female_tees = tees_obj.get("female") or []
    for t in female_tees:
        shaped = transform_tee(t, gender="female")
        if shaped is not None:
            result.append(shaped)

    return result


def main() -> int:
    # --- Pre-flight checks ------------------------------------------------
    if not INDEX_PATH.exists():
        die(
            f"Cache index not found: {INDEX_PATH}\n"
            "Phase 2 migration requires tools/api_cache_index.json and "
            "tools/api_cache/<course_id>.json files that should have been "
            "generated by the original GolfCourseAPI rebuild script. If those "
            "files live on a different machine, run this script there."
        )
    if not CACHE_DIR.exists():
        die(f"Cache directory not found: {CACHE_DIR}")
    if not COURSES_PATH.exists():
        die(f"courses.json not found: {COURSES_PATH}")

    print(f"→ Loading cache index from {INDEX_PATH}")
    index = load_json(INDEX_PATH)
    if not isinstance(index, dict):
        die("api_cache_index.json must be a {course_name: course_id} object")
    print(f"  index has {len(index)} entries")

    # Build a case-insensitive lookup
    lookup: dict[str, str] = {}
    for name, cid in index.items():
        lookup[normalize_name(str(name))] = str(cid)

    print(f"→ Loading courses.json from {COURSES_PATH}")
    courses = load_json(COURSES_PATH)
    if not isinstance(courses, list):
        die("courses.json must be a JSON array")
    print(f"  courses.json has {len(courses)} courses")

    # --- Backup -----------------------------------------------------------
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = COURSES_PATH.with_suffix(f".json.tees-{stamp}.bak")
    shutil.copy2(COURSES_PATH, backup)
    print(f"→ Backup saved to {backup.name}")

    # --- Enrichment -------------------------------------------------------
    matched = 0
    tees_added = 0
    unmatched: list[str] = []
    cache_missing: list[str] = []
    empty_tees: list[str] = []

    for course in courses:
        name = str(course.get("name") or "")
        norm = normalize_name(name)
        course_id = lookup.get(norm)

        if not course_id:
            course["tees"] = []
            unmatched.append(name)
            continue

        cache_file = CACHE_DIR / f"{course_id}.json"
        if not cache_file.exists():
            course["tees"] = []
            cache_missing.append(f"{name} (id {course_id})")
            continue

        try:
            cached = load_json(cache_file)
        except SystemExit:
            course["tees"] = []
            cache_missing.append(f"{name} (bad JSON)")
            continue

        tees = extract_tees(cached)
        course["tees"] = tees

        if tees:
            matched += 1
            tees_added += len(tees)
        else:
            empty_tees.append(name)

    # --- Write back -------------------------------------------------------
    print(f"→ Writing updated courses.json")
    with COURSES_PATH.open("w", encoding="utf-8") as f:
        json.dump(courses, f, separators=(",", ":"), ensure_ascii=False)

    # --- Summary ----------------------------------------------------------
    print()
    print("Migration complete.")
    print(f"  Courses with tees data    : {matched} / {len(courses)}")
    print(f"  Total tees added          : {tees_added}")
    print(f"  Unmatched (no cache index): {len(unmatched)}")
    print(f"  Cache file missing        : {len(cache_missing)}")
    print(f"  Matched but no valid tees : {len(empty_tees)}")
    if unmatched:
        print()
        print("First 10 unmatched courses:")
        for n in unmatched[:10]:
            print(f"  - {n}")
    if cache_missing:
        print()
        print("First 10 cache-missing courses:")
        for n in cache_missing[:10]:
            print(f"  - {n}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
