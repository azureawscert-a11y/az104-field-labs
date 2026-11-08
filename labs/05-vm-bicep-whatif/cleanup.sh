#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=SCRIPTDIR/../../common/lib.sh
source "$(dirname "$0")/../../common/lib.sh"
delete_group rg-az104-lab05 || exit 1
echo "  The VM, disk, NIC, NSG and VNet go with it."
