#!/usr/bin/env bash
# Compose the tracer commit message for a finished run.
# usage: tracer-result.sh LABEL EXIT_STATUS SECONDS LOG CONFIG_INFO
set -u
label=$1 status=$2 seconds=$3 log=$4 info=$5

verdict=FAIL
if [[ $status == 0 ]]; then verdict=PASS; fi

# Progress output redraws one line with '\r'; split it into lines and keep the last frame only.
lines=$(tr '\r' '\n' < "$log" 2>/dev/null | grep -v '^$' || true)
summary=$(grep -E '^(PASS|FAIL)' <<< "$lines" || true)
if [[ -z $summary ]]; then
    # Crash, timeout kill or assertion: no PASS/FAIL line, keep the last output instead.
    summary="(no PASS/FAIL line) $(tail -n 3 <<< "$lines")"
fi
warnings=$(grep -E '^(WARNING|%Warning|%Error)' <<< "$lines" | head -n 5 || true)

echo "$label $verdict (exit=$status, ${seconds}s)"
echo "config: $info"
echo "work: $(git symbolic-ref -q --short HEAD 2>/dev/null || echo detached)@$(git rev-parse --short HEAD 2>/dev/null || echo none)"
echo "result: $summary"
if [[ -n $warnings ]]; then echo "warnings: $warnings"; fi
