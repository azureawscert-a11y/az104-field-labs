#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
delete_group rg-az104-lab09 || exit 1
echo "  NetworkWatcherRG is shared by your subscription: leave it."
