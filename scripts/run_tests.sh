#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "==> V unit tests (src/wyr)"
v -stats test src/wyr
