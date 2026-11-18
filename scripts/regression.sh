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
# implementation (Kconfig symbol suffix) : extra .config lines per run
impls=(DIRECT ROM COMB_ADD ACCUM SHIFT_ADD PIPE_ACCUM PIPE_SHIFT_ADD WALLACE BOOTH_WALLACE SIGNED_DIRECT)
for hdl in CHISEL VERILOG; do
    for impl in "${impls[@]}"; do
        # Latency-configurable implementations are also run with a non-default latency.
        latencies=(0)
        if [[ $impl == WALLACE || $impl == BOOTH_WALLACE ]]; then latencies=(0 7); fi
        for latency in "${latencies[@]}"; do
            cat > .config <<CFG
CONFIG_HDL_${hdl}=y
CONFIG_MUL_${impl}=y
CONFIG_WIDTH=8
CONFIG_LATENCY=$latency
CFG
            if [[ $impl == SIGNED_DIRECT ]]; then echo CONFIG_TEST_SIGNED=y >> .config; fi
            make --no-print-directory olddefconfig
            make --no-print-directory test
        done
    done
done
