#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f tools/kconfig/parser.y ]]; then exit 0; fi
# Like the ysyx workbench init.sh: initialize an external teaching dependency,
# leave it untracked. Fetch only a pinned snapshot of NEMU's Kconfig sources.
revision=8e7a0fecc95b5b5d2c1f6be0ec1b703da93356c0
mkdir -p tools
source_dir=$(mktemp -d "$PWD/tools/.kconfig-source.XXXXXX")
trap 'rm -rf "$source_dir"' EXIT
git -C "$source_dir" init -q
git -C "$source_dir" remote add origin https://github.com/NJU-ProjectN/nemu.git
git -C "$source_dir" sparse-checkout init --cone
git -C "$source_dir" sparse-checkout set tools/kconfig
git -C "$source_dir" fetch --depth 1 origin "$revision"
git -C "$source_dir" checkout --detach -q FETCH_HEAD
cp -R "$source_dir/tools/kconfig" tools/kconfig
