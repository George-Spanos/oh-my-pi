#!/usr/bin/env bash
# Build omp from source at the latest release tag and symlink it into PATH.
#
# Untracked local helper (upstream does not ship it) — `git checkout` of a tag
# never touches it.
#
#   ./build-release.sh              # latest release tag -> $HOME/.local/bin/omp
#   ./build-release.sh v18.4.8      # pin a specific tag
#   OMP_BIN_DIR=~/.bun/bin ./build-release.sh
#   ./build-release.sh --force      # build even with dirty tracked files
#
# Steps: fetch tags -> resolve tag -> checkout (detached) -> bun install ->
# build pi-natives (cargo/N-API) -> compile the standalone binary -> symlink.
set -euo pipefail

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
BIN_DIR=${OMP_BIN_DIR:-$HOME/.local/bin}
LINK="$BIN_DIR/omp"
BUILT="$REPO_ROOT/packages/coding-agent/dist/omp"

TAG=""
FORCE=0
for arg in "$@"; do
	case "$arg" in
		--force) FORCE=1 ;;
		-h | --help)
			sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		-*) echo "build-release: unknown flag: $arg" >&2; exit 2 ;;
		*) TAG=$arg ;;
	esac
done

# bun is not guaranteed on PATH for non-interactive shells.
if ! command -v bun >/dev/null 2>&1; then
	export PATH="${BUN_INSTALL:-$HOME/.bun}/bin:$PATH"
fi
command -v bun >/dev/null 2>&1 || { echo "build-release: bun not found (install: curl -fsSL https://bun.sh/install | bash)" >&2; exit 1; }

# rustup installs cargo outside the default PATH; non-interactive shells miss it.
if ! command -v cargo >/dev/null 2>&1; then
	export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
fi

# pi-natives builds through cargo + the N-API CLI; opusic-sys shells out to cmake.
for tool in cargo cmake ninja; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "build-release: missing build tool '$tool' (cmake/ninja: uv tool install cmake && uv tool install ninja)" >&2
		exit 1
	}
done

# Refuse to clobber uncommitted work in the checkout.
if [ "$FORCE" -eq 0 ] && { ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; }; then
	echo "build-release: tracked files are modified in $REPO_ROOT; commit/stash them or pass --force" >&2
	git -C "$REPO_ROOT" status --short >&2
	exit 1
fi

echo "==> fetching tags"
git -C "$REPO_ROOT" fetch --tags --prune origin

if [ -z "$TAG" ]; then
	TAG=$(git -C "$REPO_ROOT" tag -l 'v*' --sort=-v:refname | head -1)
fi
[ -n "$TAG" ] || { echo "build-release: no v* tags found" >&2; exit 1; }
git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "build-release: unknown tag $TAG" >&2; exit 1; }

echo "==> checking out $TAG (detached HEAD)"
git -C "$REPO_ROOT" checkout --detach "$TAG"

echo "==> bun install"
(cd "$REPO_ROOT" && bun install --frozen-lockfile)

echo "==> building pi-natives (cargo/N-API)"
(cd "$REPO_ROOT" && bun run build:native)

# Generate the embedded-addons archive in its own process. The coding-agent
# build also does this in-process, but Bun 1.4.2's bundler intermittently
# reports `Could not resolve: "../native/embedded-addons.<tag>.tar.gz"` for the
# archive that process just wrote — observed on a fresh checkout with the file
# demonstrably on disk (52 MB, present in `readdir`). Seeding it before the
# bundler process starts makes the resolution deterministic.
echo "==> embedding native addons"
(cd "$REPO_ROOT" && bun --cwd=packages/natives run gen:native)
ARCHIVE=$(ls "$REPO_ROOT"/packages/natives/native/embedded-addons.*.tar.gz 2>/dev/null | head -1)
[ -s "$ARCHIVE" ] || { echo "build-release: embedded addons archive missing after gen:native" >&2; exit 1; }

echo "==> compiling standalone binary"
compile_binary() { (cd "$REPO_ROOT" && bun --cwd=packages/coding-agent run build); }
COMPILE_LOG=$(mktemp)
if compile_binary 2>&1 | tee "$COMPILE_LOG"; then
	rm -f "$COMPILE_LOG"
elif grep -q 'Could not resolve: "../native/embedded-addons' "$COMPILE_LOG"; then
	rm -f "$COMPILE_LOG"
	echo "build-release: bundler could not resolve the embedded-addons archive; re-seeding and retrying once" >&2
	(cd "$REPO_ROOT" && bun --cwd=packages/natives run gen:native) || exit 1
	compile_binary || exit 1
else
	rm -f "$COMPILE_LOG"
	exit 1
fi
[ -x "$BUILT" ] || { echo "build-release: expected binary missing: $BUILT" >&2; exit 1; }

echo "==> smoke test"
"$BUILT" --version

echo "==> linking $LINK -> $BUILT"
mkdir -p "$BIN_DIR"
if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
	backup="$LINK.pre-source-build.bak"
	mv -f "$LINK" "$backup"
	echo "    backed up previous install to $backup"
fi
ln -sfn "$BUILT" "$LINK"

"$LINK" --version
echo "built $(git -C "$REPO_ROOT" describe --tags) -> $LINK (detached HEAD; 'git checkout main' to return)"
