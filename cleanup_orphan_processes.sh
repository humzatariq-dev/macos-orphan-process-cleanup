#!/bin/bash
set -u
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
. "$ROOT/lib/core.sh"
. "$ROOT/lib/cli.sh"
oc_main "$@"
