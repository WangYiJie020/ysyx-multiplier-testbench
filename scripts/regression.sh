#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
backup=$(mktemp)
cp .config "$backup"
restore() {
    cp "$backup" .config
    rm -f "$backup"
    make --no-print-directory olddefconfig >/dev/null
}
trap restore EXIT
for language in CHISEL VERILOG; do
    for stage in COMB MULTI PIPE HANDSHAKE SIGNED; do
        for latency in 1 3; do
            if [[ $latency == 1 && $stage != MULTI && $stage != PIPE ]]; then continue; fi
            cat > .config <<CFG
CONFIG_IMPL_${language}=y
CONFIG_STAGE_${stage}=y
CONFIG_WIDTH=8
CONFIG_LATENCY=$latency
CFG
            if [[ $stage == SIGNED ]]; then echo CONFIG_TEST_SIGNED=y >> .config; fi
            make --no-print-directory olddefconfig
            make --no-print-directory test
        done
    done
done
