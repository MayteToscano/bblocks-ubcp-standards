#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Detect owner/repo from remote
# ----------------------------
REMOTE_URL="$(git config --get remote.origin.url || true)"
if [[ "$REMOTE_URL" =~ github\.com[:/]+([^/]+)/([^/.]+)(\.git)?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "No pude detectar OWNER/REPO del remote: $REMOTE_URL"
  exit 1
fi

BASE_URL="https://${OWNER}.github.io/${REPO}/"
NOW_DATE="$(date -u +%F)"
NOW_DT="$(date -u +%FT%TZ)"

echo "==> Repo: ${OWNER}/${REPO}"
echo "==> Base URL: ${BASE_URL}"

# ----------------------------
# Abort rebase if any + go to main
# ----------------------------
git rebase --abort 2>/dev/null || true
git checkout main 2>/dev/null || git checkout -b main

# Sync
git fetch origin
git pull --rebase origin main || true

# ----------------------------
# Clean (bblocks artifacts only)
# ----------------------------
rm -rf _sources build build-local docs
rm -f .github/workflows/process-bblocks.yml .github/workflows/process-bblocks.yaml
mkdir -p _sources .github/workflows

# ----------------------------
# bblocks-config.yaml
# ----------------------------
cat > bblocks-config.yaml <<YAML
name: ${REPO}
base-url: "${BASE_URL}"
identifier-prefix: ogc.ubcp.
imports:
  - "https://opengeospatial.github.io/bblocks/register.json"
YAML

# ----------------------------
# Helper: JSON array builder for dependsOn
# Usage: json_array "a" "b" ...
# ----------------------------
json_array () {
  if [[ $# -eq 0 ]]; then
    echo "[]"
    return
  fi
  echo "["
  local i=0
  local n=$#
  for v in "$@"; do
    i=$((i+1))
    if [[ $i -lt $n ]]; then
      printf '  "%s",\n' "$v"
    else
      printf '  "%s"\n' "$v"
    fi
  done
  echo "]"
}

# ----------------------------
# Helper: create a building block under _sources/<folder>/
# mkbb <folder> <itemIdentifier> <name> <abstract> <group> [dependsOn...]
# ----------------------------
mkbb () {
  local folder="$1"
  local itemIdentifier="$2"
  local name="$3"
  local abstract="$4"
  local group="$5"
  shift 5
  local deps_json
  deps_json="$(json_array "$@")"

  mkdir -p "_sources/${folder}/examples"

  cat > "_sources/${folder}/bblock.json" <<JSON
{
  "\$schema": "metaschema.yaml",
  "itemIdentifier": "${itemIdentifier}",
  "name": "${name}",
  "abstract": "${abstract}",
  "itemClass": "schema",
  "status": "under-development",
  "version": "0.1.0",
  "dateTimeAddition": "${NOW_DT}",
  "dateOfLastChange": "${NOW_DATE}",
  "tags": ["ubcp", "${group}"],
  "group": "${group}",
  "conformanceClasses": [
    "${BASE_URL}conformance/${itemIdentifier}"
  ],
  "dependsOn": ${deps_json}
}
JSON

  cat > "_sources/${folder}/schema.yaml" <<'YAML'
$schema: "https://json-schema.org/draft/2020-12/schema"
type: object
additionalProperties: false
properties: {}
YAML

  cat > "_sources/${folder}/description.md" <<MD
# ${name}

${abstract}
MD

  cat > "_sources/${folder}/examples/example.json" <<'JSON'
{}
JSON

  cat > "_sources/${folder}/examples.yaml" <<YAML
- name: example
  path: examples/example.json
YAML
}

# ----------------------------
# STANDARD blocks
# ----------------------------
mkbb "standards.iso19115"        "ogc.ubcp.std.iso19115"       "ISO 19115 Metadata" "Core geospatial metadata elements used across the profile." "standards"
mkbb "standards.iso19115-2"      "ogc.ubcp.std.iso19115_2"     "ISO 19115-2 Acquisition Metadata" "Acquisition-related metadata extension used for sensors/platform/collection lineage." "standards"
mkbb "standards.iso19111"        "ogc.ubcp.std.iso19111"       "ISO 19111 CRS" "Coordinate Reference Systems and referencing by coordinates (CRS URIs)." "standards"
mkbb "standards.iso19157"        "ogc.ubcp.std.iso19157"       "ISO 19157 Data Quality" "Data quality and accuracy elements used for precision reporting." "standards"
mkbb "standards.ogc-geopose"     "ogc.ubcp.std.ogc_geopose"    "OGC GeoPose" "Pose/orientation representation for sensors/platform/camera frames." "standards"
mkbb "standards.ogc-sensorml"    "ogc.ubcp.std.ogc_sensorml"   "OGC SensorML" "Sensor and platform description model." "standards"
mkbb "standards.w3c-prov-o"      "ogc.ubcp.std.w3c_prov"       "W3C PROV-O" "Provenance model for processing lineage." "standards"
mkbb "standards.stac-core"       "ogc.ubcp.std.stac_core"      "STAC Core" "STAC core for discovery and structuring assets." "standards"
mkbb "standards.stac-raster"     "ogc.ubcp.std.stac_raster"    "STAC Raster" "STAC Raster extension for raster band metadata." "standards" "ogc.ubcp.std.stac_core"

# ----------------------------
# UAV blocks (core + extensions)
# ----------------------------
mkbb "core" "ogc.ubcp.core" "UBCP Core UAV Module (Mandatory Base)" \
"Minimum interoperable UAV capture metadata: temporal/spatial reference, orientation, sensor ID, CRS declaration and lineage." \
"uav" \
"ogc.ubcp.std.iso19115" "ogc.ubcp.std.iso19111" "ogc.ubcp.std.iso19115_2" "ogc.ubcp.std.ogc_geopose" "ogc.ubcp.std.ogc_sensorml" "ogc.ubcp.std.w3c_prov" "ogc.ubcp.std.stac_core"

mkbb "extension.thermal" "ogc.ubcp.extension.thermal" "UBCP Thermal Extension" \
"Thermal capture parameters (calibration, radiometric model)." "uav" "ogc.ubcp.core"

mkbb "extension.multispectral" "ogc.ubcp.extension.multispectral" "UBCP Multispectral Extension" \
"Multispectral band metadata and reflectance conversion model." "uav" "ogc.ubcp.core" "ogc.ubcp.std.stac_raster"

mkbb "extension.lidar" "ogc.ubcp.extension.lidar" "UBCP LiDAR Extension" \
"Point cloud acquisition parameters (scan pattern, density, intensity calibration)." "uav" "ogc.ubcp.core" "ogc.ubcp.std.iso19157"

mkbb "extension.rtk" "ogc.ubcp.extension.rtk" "UBCP RTK Extension" \
"RTK/GNSS positioning mode and precision reporting." "uav" "ogc.ubcp.core" "ogc.ubcp.std.iso19157"

# ----------------------------
# Aggregator/Profile block
# ----------------------------
mkdir -p "_sources/profile/examples"

cat > "_sources/profile/bblock.json" <<JSON
{
  "\$schema": "metaschema.yaml",
  "itemIdentifier": "ogc.ubcp.profile",
  "name": "UBCP Profile (Aggregator)",
  "abstract": "Entry-point building block grouping UBCP core + extensions and linking the profile as a whole.",
  "itemClass": "schema",
  "status": "under-development",
  "version": "0.1.0",
  "dateTimeAddition": "${NOW_DT}",
  "dateOfLastChange": "${NOW_DATE}",
  "tags": ["ubcp", "uav", "profile"],
  "group": "uav",
  "superBBlock": true,
  "conformanceClasses": [
    "${BASE_URL}conformance/ogc.ubcp.profile"
  ],
  "dependsOn": [
    "ogc.ubcp.core",
    "ogc.ubcp.extension.thermal",
    "ogc.ubcp.extension.multispectral",
    "ogc.ubcp.extension.lidar",
    "ogc.ubcp.extension.rtk"
  ]
}
JSON

cat > "_sources/profile/schema.yaml" <<'YAML'
$schema: "https://json-schema.org/draft/2020-12/schema"
type: object
additionalProperties: true
YAML

cat > "_sources/profile/description.md" <<'MD'
# UBCP Profile (Aggregator)

This is the entry point for the whole profile:
- Core
- Thermal / Multispectral / LiDAR / RTK extensions
MD

cat > "_sources/profile/examples/example.json" <<'JSON'
{}
JSON

cat > "_sources/profile/examples.yaml" <<'YAML'
- name: example
  path: examples/example.json
YAML

# ----------------------------
# Workflow (working reusable workflow)
# ----------------------------
cat > ".github/workflows/process-bblocks.yml" <<'YAML'
name: Validate and process Building Blocks
on:
  workflow_dispatch:
  push:
    branches:
      - master
      - main

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  validate-and-process:
    uses: opengeospatial/bblocks-postprocess/.github/workflows/validate-and-process.yml@master
YAML

# ----------------------------
# Commit & push
# ----------------------------
git add -A
git commit -m "Reset: rebuild _sources with standards + UAV blocks + working workflow" || true
git push origin main

echo ""
echo "==> OK. Espera a que Actions acabe y mira:"
echo "    ${BASE_URL}"
