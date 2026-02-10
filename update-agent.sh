#!/usr/bin/env bash
set -euo pipefail

# Refresh local data caches from Metadata-Questionnaire-CU-Series.
# Usage:
#   ./update-agent.sh
#
# Token resolution order:
#   1) GITHUB_TOKEN
#   2) HIVE_BRAIN_GH_TOKEN_DFO_PAC_SCI
#   3) gh auth token (if logged in)

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$ROOT_DIR/data"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE_OWNER="dfo-pacific-science"
SOURCE_REPO="Metadata-Questionnaire-CU-Series"
CU_PATH="DATA/x_CU_Level_Metadata.csv"
DESC_PATH="DATA/x_MetadataDescriptions.csv"

mkdir -p "$DATA_DIR"

resolve_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$GITHUB_TOKEN"
    return
  fi
  if [[ -n "${HIVE_BRAIN_GH_TOKEN_DFO_PAC_SCI:-}" ]]; then
    printf '%s' "$HIVE_BRAIN_GH_TOKEN_DFO_PAC_SCI"
    return
  fi
  if command -v gh >/dev/null 2>&1; then
    gh auth token 2>/dev/null || true
  fi
}

fetch_via_gh_api() {
  local token="$1"
  local source_path="$2"
  local out_file="$3"

  GH_TOKEN="$token" gh api \
    -H "Accept: application/vnd.github.v3.raw" \
    "/repos/${SOURCE_OWNER}/${SOURCE_REPO}/contents/${source_path}" > "$out_file"
}

fetch_via_raw_url() {
  local source_path="$1"
  local out_file="$2"

  curl -fsSL \
    "https://raw.githubusercontent.com/${SOURCE_OWNER}/${SOURCE_REPO}/main/${source_path}" \
    -o "$out_file"
}

fetch_file() {
  local source_path="$1"
  local out_file="$2"

  local token
  token="$(resolve_token)"

  if [[ -n "$token" ]] && command -v gh >/dev/null 2>&1; then
    if fetch_via_gh_api "$token" "$source_path" "$out_file"; then
      return 0
    fi
  fi

  # Works only if source repo/path is publicly accessible.
  fetch_via_raw_url "$source_path" "$out_file"
}

echo "Refreshing CU metadata cache..."
fetch_file "$CU_PATH" "$TMP_DIR/cu_metadata.csv"
fetch_file "$DESC_PATH" "$TMP_DIR/descriptions_raw.csv"

TMP_DIR="$TMP_DIR" DATA_DIR="$DATA_DIR" python - <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import csv
import os

data_dir = Path(os.environ["DATA_DIR"])
tmp_dir = Path(os.environ["TMP_DIR"])

cu_file = tmp_dir / "cu_metadata.csv"
desc_raw = tmp_dir / "descriptions_raw.csv"

# Clean description file by stripping commented rows.
desc_lines = desc_raw.read_text(encoding="utf-8", errors="ignore").splitlines()
clean_desc = [ln for ln in desc_lines if not ln.startswith("#")]

(data_dir / "cu_metadata_cache.csv").write_text(cu_file.read_text(encoding="utf-8", errors="ignore"), encoding="utf-8")
(data_dir / "descriptions_cache.csv").write_text("\n".join(clean_desc) + "\n", encoding="utf-8")
(data_dir / "last_refresh.txt").write_text(datetime.now(timezone.utc).isoformat() + "\n", encoding="utf-8")

for name in ["cu_metadata_cache.csv", "descriptions_cache.csv"]:
    path = data_dir / name
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.reader(fh))
    print(f"{name}: {max(len(rows)-1, 0)} rows, {len(rows[0]) if rows else 0} columns")

print("Refresh complete.")
PY

