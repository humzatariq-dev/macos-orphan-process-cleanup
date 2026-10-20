#!/bin/bash
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
[ "${BASH_VERSINFO[0]}" = 3 ] && [ "${BASH_VERSINFO[1]}" = 2 ] || {
    echo 'Run with stock /bin/bash 3.2; refusing to substitute another Bash.' >&2; exit 1;
}
printf 'Bash: %s\n' "$BASH_VERSION"
sw_vers
uname -m
command -v shellcheck >/dev/null || { echo 'Install development-only ShellCheck 0.11.0.' >&2; exit 1; }
while IFS= read -r file; do
    /bin/bash -n "$file"
    shellcheck -x -S warning -s bash "$file"
done < <(find . -name '*.sh' -not -path './dist/*' -not -path './.git/*' | sort)
/bin/bash -n orphan-cleanup
shellcheck -x -S warning -s bash orphan-cleanup
/bin/bash tests/run.sh
/bin/bash tests/install.sh
/bin/bash scripts/package.sh
/bin/bash tests/package.sh
