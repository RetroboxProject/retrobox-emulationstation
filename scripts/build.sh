#!/usr/bin/env bash
# Configure and build EmulationStation from a patched checkout.
#
#   scripts/build.sh SRC
#
# Desktop-Linux build: desktop OpenGL (no GLES), no CEC, system pugixml.
# The binary ends up in SRC/emulationstation (upstream's in-source layout).
#
# Environment: MICROARCH  baseline (default) or v3, see common.sh. Each level
#                         uses its own build directory, SRC/build-<MICROARCH>.
#
#   SCREENSCRAPER_DEV_LOGIN     "devid=<id>&devpassword=<password>", the developer
#                               login of ScreenScraper. EmulationStation only
#                               includes the ScreenScraper scraper when it is
#                               compiled in; without it the scraper is not in
#                               the menu at all.
#   SCREENSCRAPER_SOFTNAME      software name sent to ScreenScraper (default:
#                               Retrobox-Emulationstation); use the one the
#                               login was registered for.
# The login ends up in plain text inside the binary: see README.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=scripts/common.sh
. "${HERE}/common.sh"

SRC="${1:?usage: build.sh SRC}"
SRC="$(cd "${SRC}" >/dev/null 2>&1 && pwd -P)"
BUILD="${SRC}/build-${MICROARCH}"

# cmake takes its initial CMAKE_C(XX)_FLAGS from these.
export CFLAGS="${CFLAGS:+${CFLAGS} }${MARCH_FLAGS}"
export CXXFLAGS="${CXXFLAGS:+${CXXFLAGS} }${MARCH_FLAGS}"

# --- ScreenScraper -------------------------------------------------------------
ss_args=()
if [[ -n "${SCREENSCRAPER_DEV_LOGIN:-}" ]]; then
    # A value pasted into a web form often carries a trailing newline or
    # spaces, which would end up inside the compiled string: trim them.
    login="${SCREENSCRAPER_DEV_LOGIN}"
    login="${login#"${login%%[![:space:]]*}"}"
    login="${login%"${login##*[![:space:]]}"}"
    # Validate the shape without ever printing the value: the diagnostics only
    # say what is wrong with its structure.
    if [[ ! "${login}" =~ ^devid=[^\&[:space:]]+\&devpassword=[^\&[:space:]]+$ ]]; then
        echo "build.sh: SCREENSCRAPER_DEV_LOGIN must look like devid=<id>&devpassword=<password> (nothing else, no spaces)" >&2
        [[ "${login}" == devid=* ]] || echo "build.sh:   it does not start with 'devid='" >&2
        [[ "${login}" == *'&devpassword='* ]] || echo "build.sh:   it has no '&devpassword=' part" >&2
        separators="${login//[^&]/}"
        echo "build.sh:   it has ${#separators} '&' separator(s); exactly 1 is expected" >&2
        exit 1
    fi
    ss_args=(
        "-DSCREENSCRAPER_DEV_LOGIN=${login}"
        "-DSCREENSCRAPER_SOFTNAME=${SCREENSCRAPER_SOFTNAME:-Retrobox-Emulationstation}"
    )
    echo "build.sh: ScreenScraper support: ON (softname ${SCREENSCRAPER_SOFTNAME:-Retrobox-Emulationstation})"
else
    echo "build.sh: ScreenScraper support: OFF (SCREENSCRAPER_DEV_LOGIN is not set, so the scraper will not exist)" >&2
fi

cmake -S "${SRC}" -B "${BUILD}" -G Ninja \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBATOCERA=OFF -DCEC=OFF \
    -DGL=ON -DGLES=OFF -DGLES2=OFF -DGLES3=OFF \
    -DUSE_SYSTEM_PUGIXML=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    "${ss_args[@]}"
verify_march "${BUILD}/compile_commands.json"
cmake --build "${BUILD}" -j"$(nproc)"

[[ -x "${SRC}/emulationstation" ]] || { echo "build.sh: no emulationstation binary produced" >&2; exit 1; }
echo "build.sh: built ${SRC}/emulationstation"
