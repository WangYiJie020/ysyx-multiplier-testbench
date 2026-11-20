#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/request.cpp" <<'CPP'
#include "model.h"

#include <cassert>
#include <limits>

using sim::Request;

constexpr auto minOperand = -int64_t(sim::operandMask >> 1) - 1;
constexpr auto fits = Request::constant<minOperand, sim::operandMask>(true, true);
static_assert(fits.a == (uint64_t{1} << (sim::width - 1)));
static_assert(fits.b == sim::operandMask && fits.aSigned && fits.bSigned);
static_assert(Request::constant<-1, 0>().a == sim::operandMask);

#ifdef CHECK_CONSTANT
constexpr auto truncated = Request::constant<256, -128>();
static_assert(truncated.a == 0 && truncated.b == 128);
#endif

int main() {
    volatile int64_t a = minOperand;
    volatile uint64_t b = sim::operandMask;
    const Request inRange{a, b, true, true};
    assert(inRange.a == fits.a && inRange.b == fits.b);
#ifdef CHECK_LITERAL
    const Request literal{-129, 255};
    assert(literal.a == 127 && literal.b == 255);
#endif
#ifdef CHECK_RUNTIME
    a = -129;
    b = 256;
    const Request runtime{a, b};
    assert(runtime.a == 127 && runtime.b == 0);
    a = std::numeric_limits<int64_t>::min();
    const Request mostNegative{a, 0};
    assert(mostNegative.a == 0);
#endif
}
CPP

build() {
    local width=$1
    shift
    "${CXX:-c++}" -std=c++17 -Wall -Wextra -I sim -DOPERAND_WIDTH="$width" \
        -DTEST_SIGNED=0 -DTEST_EXHAUSTIVE=0 "$@" "$tmp/request.cpp" sim/model.cpp \
        -o "$tmp/request" 2> "$tmp/compiler.log" || { cat "$tmp/compiler.log" >&2; return 1; }
}

for width in 1 8 64; do
    build "$width" -O2 -Werror
    "$tmp/request" 2> "$tmp/runtime.log"
    test ! -s "$tmp/runtime.log"
done

build 8 -O0 -DCHECK_CONSTANT
grep -q 'warning: .*Request operand will be truncated' "$tmp/compiler.log"
"$tmp/request" 2> "$tmp/runtime.log"
test ! -s "$tmp/runtime.log"

build 8 -O2 -DCHECK_LITERAL -DCHECK_RUNTIME
grep -q 'warning: .*Request operand will be truncated' "$tmp/compiler.log"
"$tmp/request" 2> "$tmp/runtime.log"
diff -u - "$tmp/runtime.log" <<'EXPECTED'
warning: Request operand a=-129 truncated to 8 bits (0x7f)
warning: Request operand b=256 truncated to 8 bits (0x0)
warning: Request operand a=-9223372036854775808 truncated to 8 bits (0x0)
EXPECTED
printf 'PASS: Request truncation diagnostics\n'
