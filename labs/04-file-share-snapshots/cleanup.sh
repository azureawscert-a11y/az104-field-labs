#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
rm -rf "$(dirname "$0")/restored" "$(dirname "$0")/snapshot.txt" /tmp/travel-policy.txt
delete_group rg-az104-lab04 || exit 1
