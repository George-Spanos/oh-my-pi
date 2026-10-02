# Personal build setup

Local-only branch (`personal-setup`) on top of `main`. Carries my omp build
helper and agent config so a fresh machine is two commands from a working build.

## New machine

```bash
git clone git@github.com:George-Spanos/oh-my-pi.git
cd oh-my-pi
git checkout personal-setup

./build-release.sh                                   # latest release tag -> ~/.local/bin/omp
mkdir -p ~/.omp/agent && cp omp-config.yml ~/.omp/agent/config.yml
```

## Requirements

- `bun`, `cargo`, `cmake`, `ninja` on `PATH`
- `~/.local/bin` on `PATH` (where `build-release.sh` symlinks `omp`)

`build-release.sh --help` lists the flags; pass a tag to pin a version, e.g.
`./build-release.sh v18.4.8`.
