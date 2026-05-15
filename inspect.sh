#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
v -o wyr-inspect src/inspect
exec ./wyr-inspect "$@"
