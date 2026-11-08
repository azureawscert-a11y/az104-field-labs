#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
rm -f "$HERE/sas.txt" /tmp/q3-report.txt
delete_group rg-az104-lab03 || exit 1
