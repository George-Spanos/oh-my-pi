#!/usr/bin/env bash
# Install the build dependencies for build-release.sh on Debian/Ubuntu.
#
#   ./install-deps.sh             # apt + bun + rustup + pinned toolchain
#   ./install-deps.sh --apt-only  # apt packages only
#
# Mirrors the natives-builder stage of ./Dockerfile: the C toolchain, CMake and
# Ninja for opusic-sys, clang/libclang for bindgen, plus bun and rustup (apt's
# rustc is older than the nightly pinned in rust-toolchain.toml).
set -euo pipefail

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
APT_ONLY=0
for arg in "$@"; do
	case "$arg" in
		--apt-only) APT_ONLY=1 ;;
		-h | --help)
			sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*) echo "install-deps: unknown flag: $arg" >&2; exit 2 ;;
	esac
done

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	command -v sudo >/dev/null 2>&1 || { echo "install-deps: not root and sudo not found" >&2; exit 1; }
	SUDO=sudo
fi

echo "==> apt: build deps"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
	build-essential pkg-config libssl-dev \
	curl ca-certificates unzip git \
	clang libclang-dev cmake make ninja-build

if [ "$APT_ONLY" -eq 1 ]; then
	echo "==> apt-only: done"
	exit 0
fi

# bun ships no apt package.
if ! command -v bun >/dev/null 2>&1 && [ ! -x "${BUN_INSTALL:-$HOME/.bun}/bin/bun" ]; then
	echo "==> installing bun"
	curl -fsSL https://bun.sh/install | bash
fi
export PATH="${BUN_INSTALL:-$HOME/.bun}/bin:$PATH"
command -v bun >/dev/null 2>&1 || { echo "install-deps: bun still not on PATH" >&2; exit 1; }

if ! command -v rustup >/dev/null 2>&1; then
	echo "==> installing rustup"
	curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal
fi
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
command -v rustup >/dev/null 2>&1 || { echo "install-deps: rustup still not on PATH" >&2; exit 1; }

echo "==> installing toolchain pinned by rust-toolchain.toml"
(cd "$REPO_ROOT" && rustup show)

echo "==> done: bun $(bun --version), $(cargo --version)"
echo "    ensure ~/.local/bin and ${CARGO_HOME:-$HOME/.cargo}/bin are on PATH, then run ./build-release.sh"
