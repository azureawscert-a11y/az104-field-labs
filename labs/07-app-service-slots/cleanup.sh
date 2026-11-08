#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
delete_group rg-az104-lab07 || exit 1
echo "  The S1 plan bills by the hour until it is gone."
