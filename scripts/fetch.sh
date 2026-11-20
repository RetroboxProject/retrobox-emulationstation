#!/usr/bin/env bash
# Fetch batocera-emulationstation at a given ref and apply patches/*.patch.
#
#   scripts/fetch.sh [--ref REF] [--no-patch] DEST
#
# REF is a branch, tag or commit id (default: $ES_REF, else master). The
# patches are applied in file-name order; if one does not apply, the script
# stops and names it, so a drifting upstream is easy to diagnose: it also
# prints the hunks that don't apply and, for each one, the upstream code where
# it should go now, so the log alone is enough to redo the patch.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=scripts/common.sh
. "${HERE}/common.sh"

REF="${ES_REF:-master}"
APPLY=1
DEST=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref)      REF="${2:?--ref needs a value}"; shift 2 ;;
        --no-patch) APPLY=0; shift ;;
        -h|--help)  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)         echo "fetch.sh: unknown option: $1" >&2; exit 2 ;;
        *)          DEST="$1"; shift ;;
    esac
done
[[ -n "${DEST}" ]] || { echo "usage: fetch.sh [--ref REF] [--no-patch] DEST" >&2; exit 2; }
if [[ -e "${DEST}" ]] && [[ -n "$(ls -A "${DEST}" 2>/dev/null)" ]]; then
    echo "fetch.sh: ${DEST} exists and is not empty" >&2
    exit 1
fi

mkdir -p "${DEST}"
git -C "${DEST}" init -q
git -C "${DEST}" remote add origin "${UPSTREAM_URL}"
git -C "${DEST}" fetch -q --depth 1 origin "${REF}"
git -C "${DEST}" checkout -q FETCH_HEAD
git -C "${DEST}" submodule update -q --init --depth 1
echo "fetch.sh: upstream ${REF} -> $(git -C "${DEST}" rev-parse --short=12 HEAD)"

[[ "${APPLY}" -eq 1 ]] || exit 0

# Why a patch doesn't apply: apply what does (--reject, DEST is left as is,
# since the script fails anyway), then print each rejected hunk and the
# upstream lines around where it was meant to go (20 lines of margin).
function explain_rejects() {
    local patch="$1" rej file
    echo "fetch.sh: hunk by hunk:" >&2
    git -C "${DEST}" apply --reject --whitespace=nowarn "${patch}" >&2 2>&1 || true
    while IFS= read -r -d '' rej; do
        file="${rej%.rej}"
        echo >&2
        echo "==== rejected from ${file#"${DEST}/"}:" >&2
        cat "${rej}" >&2
        [[ -f "${file}" ]] || { echo "==== (that file does not exist upstream any more)" >&2; continue; }
        grep -E '^@@ -[0-9]+' "${rej}" | while read -r _ old _; do
            local start="${old#-}" count=1 from to
            [[ "${start}" == *,* ]] && { count="${start#*,}"; start="${start%,*}"; }
            from=$(( start > 20 ? start - 20 : 1 ))
            to=$(( start + count + 20 ))
            echo "==== upstream ${file#"${DEST}/"}, lines ${from}-${to}, now:" >&2
            awk -v from="${from}" -v to="${to}" 'NR >= from && NR <= to { printf "%6d  %s\n", NR, $0 }' \
                "${file}" >&2
        done
    done < <(find "${DEST}" -name '*.rej' -not -path '*/.git/*' -print0 | sort -z)
}

shopt -s nullglob
patches=("${REPO_ROOT}"/patches/*.patch)
[[ ${#patches[@]} -gt 0 ]] || { echo "fetch.sh: no patches found" >&2; exit 1; }
err="$(mktemp)"
trap 'rm -f "${err}"' EXIT
for patch in "${patches[@]}"; do
    name="$(basename "${patch}")"
    if ! git -C "${DEST}" apply --check "${patch}" 2>"${err}"; then
        echo "fetch.sh: ${name} does not apply to upstream ${REF} ($(git -C "${DEST}" rev-parse --short=12 HEAD)):" >&2
        cat "${err}" >&2
        explain_rejects "${patch}"
        exit 1
    fi
    git -C "${DEST}" apply --whitespace=nowarn "${patch}"
    echo "fetch.sh: applied ${name}"
done
