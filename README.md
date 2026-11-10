# retrobox-emulationstation

Packaging for the [Retrobox](https://github.com/manu-romero-411/retrobox-core)
frontend: [batocera-emulationstation](https://github.com/batocera-linux/batocera-emulationstation)
plus a small patch series, built as `.deb` and `.rpm` by GitHub Actions.

Nothing from upstream is vendored here. Each build fetches upstream, applies
`patches/*.patch`, compiles it, packages it and tests the package in a clean
container.

## Packages

The set of distributions is not written in the workflow: each run resolves it
(`scripts/resolve-matrix.py`, from endoflife.date, only releases whose container
image already exists) as the **latest Debian stable, the last two Ubuntu LTS and
the last two Fedora releases**. Today that is:

| Distribution          | Format | Built on                 |
|-----------------------|--------|--------------------------|
| Debian 13             | `.deb` | `debian:trixie`          |
| Ubuntu 24.04 / 26.04  | `.deb` | `ubuntu:24.04`, `ubuntu:26.04` |
| Fedora 43 / 44        | `.rpm` | `fedora:43`, `fedora:44` |

Download the file for your distribution from the
[latest release](../../releases/latest). The package depends on `retrobox-core`.

### Architectures

Every release has each package for two CPU targets. The architecture is the
last part of the file name, written the way each distribution family does it:

| Target | `.deb` (Debian, Ubuntu) | `.rpm` (Fedora) | Runs on |
|--------|-------------------------|-----------------|---------|
| x86-64 | `..._amd64.deb` | `....x86_64.rpm` | any 64-bit PC |
| 64-bit ARM | `..._arm64.deb` | `....aarch64.rpm` | ARM64 machines |

There are no x86-64-v3 builds for now. `scripts/build.sh` and `build-deb.sh`
still accept `MICROARCH=v3` for local builds.

### Versions

Each package is built from the latest commit of upstream `master` and carries
that commit's UTC date and time as its version:

| Format | Example |
|--------|---------|
| `.deb` | `20261013.143005-12~ubuntu24.04` |
| `.rpm` | `20261013.143005-12.fc44` |

The release is tagged `build-20261013_143005-486b719-<hash>` (the same stamp,
`YYYYMMDD_HHMMSS`; Debian versions cannot contain `_`, hence the dot). The
trailing number is the run number of the workflow, and the commit id (also in the release title) is in
`/usr/share/doc/retrobox-emulationstation/BUILDINFO`.

On Fedora, `libvlc` comes from [RPM Fusion](https://rpmfusion.org/) (free),
which has to be enabled.

## What gets installed

| Path                                    | Content                              |
|-----------------------------------------|--------------------------------------|
| `/opt/retrobox/frontend/emulationstation` | the binary                         |
| `/opt/retrobox/frontend/resources/`     | fonts, images, default data          |
| `/opt/retrobox/frontend/locale/`        | translations                         |
| `/usr/bin/retrobox-emulationstation`    | symlink to the binary                |

There is no `.desktop` entry and no icon: run `retrobox` (from
`retrobox-core`) to get the whole environment. `retrobox-emulationstation` on
its own is plain EmulationStation and keeps its data in `~/.emulationstation`.

## Patches

| Patch | What it does |
|-------|--------------|
| `0001` | Window title, `.gitignore` for generated locale files |
| `0002` | Desktop integration in `ApiSystem`/`GuiMenu`/`Settings` (Kodi, suspend, quit menu, quit entry shown by default) |
| `0003` | Null-safety for the gamelist cursor |
| `0004` | Shutdown/reboot through KDE |
| `0005` | Take the executable path from `/proc/self/exe`, so the symlink in `/usr/bin` finds `resources/` and `locale/` |
| `0006` | With `RETROBOX_ES_MENU_THEME` set to a file, write there on every game launch the resolved menu theme (colours, fonts with their pixel sizes, background, icons, the help prompts' style and icons, plus language and button settings) as JSON, for `retrobox-overlay` |
| `0008` | Write that menu theme also once started, after the themes are reloaded and whenever the settings are saved, so the overlay is themed in EmulationStation too (before any game) and follows changes such as the confirm button or the 12-hour clock |

They are split by topic so that when upstream drifts, the one that fails
tells you where to look.

## The workflow (`.github/workflows/build.yml`)

1. `resolve` – resolves the upstream commit, computes the release tag
   (`build-<commit date>-<sha>-<hash of this repo's build inputs>`), stops if that
   release already exists, and checks that the patches apply.
2. `build` – one job per distribution **and architecture** (2 per distribution, 10 today, `arm64`/`aarch64` on native ARM runners): install build dependencies, fetch,
   patch, compile, package.
3. `test` – installs each package, on a runner of its own architecture, in a **clean** container (with a stub
   `retrobox-core`) and checks files, libraries and `--help` through `$PATH`.
4. `publish` – creates the GitHub release.
5. `notify` – on a failed scheduled run, opens one `upstream-drift` issue.

It runs **every two months, on the 13th** (January, March, May, July,
September, November), **on demand** from Actions → build → *Run workflow*
(with an optional upstream ref), and when patches or packaging change. Pull requests build and test but never publish.

### When a patch stops applying

```bash
scripts/fetch.sh work/src          # names the patch that fails
cd work/src
git apply --reject ../../patches/0002-*.patch   # fix by hand, then regenerate:
git diff -- <files> > ../../patches/0002-....patch
```

## Building locally

```bash
sudo scripts/install-build-deps.sh                  # Debian/Ubuntu or Fedora
scripts/fetch.sh work/src                           # --ref <branch|tag|sha>
scripts/build.sh work/src                           # MICROARCH=v3 for x86-64-v3
PKG_REVISION=1 scripts/build-deb.sh work/src dist   # or build-rpm.sh (same MICROARCH)
```

## Licensing

* This repository (scripts, workflow, packaging) is MIT, see `LICENSE`.
* `patches/` are derivative works of batocera-emulationstation, which is MIT
  (originally EmulationStation by Alec Lofquist), and are MIT as well. Upstream's
  copyright notice must therefore be kept: it is installed, verbatim, in
  `/usr/share/doc/retrobox-emulationstation/licenses/`. **Do not add to the
  patches code taken from a project with a different licence (GPL, for
  instance) without checking that it is compatible**: the whole binary would
  be affected.
* The binary also contains code of third parties and ships fonts with other
  licences (BSD-2-Clause, Zlib, Unlicense, RSA-MD, LGPL-2.1+, Apache-2.0,
  OFL-1.1, Ubuntu Font Licence). They are described in `packaging/copyright`
  and their texts are in `licenses/` (canonical texts kept here) and copied
  from the upstream tree at build time (verbatim files).
* `scripts/check-licenses.sh` runs in every build and **fails** when upstream
  adds a bundled library, a font, or a source file with a copyright notice that
  is not listed in `packaging/licenses-reviewed.txt`. When that happens, read
  the licence of the new component, describe it in `packaging/copyright`, and
  add it to the list. `ALLOW_UNREVIEWED_LICENSES=1` downgrades the failure to a
  warning for test builds only.
* Libraries linked dynamically (SDL2, FreeImage, VLC, ...) are not part of the
  package and keep the licences they have in your distribution.
* Known gap: upstream gives no origin or licence for its icons, flags, images
  and sounds in `resources/`; they are distributed under upstream's licence.

## ScreenScraper

EmulationStation includes the ScreenScraper scraper **only if ScreenScraper's
developer login is compiled in**. Without it the scraper is not in the menu at
all (the same holds for TheGamesDB, HfsDB and RetroAchievements with their own
keys). The login identifies the *software*; each user still enters their own
ScreenScraper account in the menu.

To build with it, give the build a developer login registered for the software:

```bash
SCREENSCRAPER_DEV_LOGIN='devid=<id>&devpassword=<password>' \
SCREENSCRAPER_SOFTNAME='Retrobox-Emulationstation' \
    scripts/build.sh work/src
```

In GitHub Actions, create the **repository secret `SCREENSCRAPER_DEV_LOGIN`**
(Settings → Secrets and variables → Actions) with the same
`devid=...&devpassword=...` value. The workflow then builds with it, the test
job requires the scraper to be in the binary, `BUILDINFO` says
`screenscraper: yes`, and the release notes say so. `SCREENSCRAPER_SOFTNAME`
defaults to `Retrobox-Emulationstation`; use the name the login was registered
for.

**The login ends up in plain text inside the binary** (`strings` finds it), so
anyone who downloads a public release can read it, and ScreenScraper can
revoke it. Decide whether you accept that: if not, keep the secret out of the
repository and build privately. GitHub masks the secret in the logs (the
workflow also masks its two values separately), but only inside the workflow.
Pull requests from forks cannot read the secret and build without it.

Without the secret the packages build and pass the tests, just without
ScreenScraper.
