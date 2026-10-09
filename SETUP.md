# Personal build setup

Local-only branch (`personal-setup`) on top of `main`. Carries my omp build
helper and agent config so a fresh machine is two commands from a working build.

## New machine

```bash
git clone git@github.com:George-Spanos/oh-my-pi.git
cd oh-my-pi
git checkout personal-setup

./install-deps.sh                                    # Debian/Ubuntu: apt + bun + rustup + pinned toolchain
./build-release.sh                                   # latest release tag -> ~/.local/bin/omp
mkdir -p ~/.omp/agent && cp omp-config.yml ~/.omp/agent/config.yml
```

## Requirements

- `bun`, `cargo`, `cmake`, `ninja` on `PATH` (installed by `install-deps.sh`)
- `~/.local/bin` and `~/.cargo/bin` on `PATH` (`~/.local/bin` is where
  `build-release.sh` symlinks `omp`)
- `BRAVE_API_KEY` exported from the shell that launches `omp` (mine lives in
  `~/.bashrc`). `omp-config.yml` pins Brave as the *only* web provider
  (`retry.fallbackChains.web: []` disables the built-in priority chain), so a
  missing key makes `web_search` fail outright instead of falling back to
  another engine. A non-interactive shell that skips `~/.bashrc` will not have
  the key.

`build-release.sh --help` lists the flags; pass a tag to pin a version, e.g.
`./build-release.sh v18.4.8`.
