#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
delete_group rg-az104-lab06 || exit 1
echo "  Data disks are separate resources: deleting the group removes them too."
