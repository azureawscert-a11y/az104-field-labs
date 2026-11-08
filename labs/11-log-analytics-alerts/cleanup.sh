#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
rm -f /tmp/lab11.txt
delete_group rg-az104-lab11 || exit 1
echo "  The workspace, storage, alert and action group go with it."
