#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
bash tests/test_pam_common.sh
bash tests/test_wrappers.sh
bash tests/test_install.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
