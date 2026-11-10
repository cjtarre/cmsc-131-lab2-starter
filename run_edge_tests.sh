#!/usr/bin/env bash

# Additional edge-case tests for CMSC 131 Lab 2.
# Runs independently of the provided test suite.

set -uo pipefail

# Build the project without unnecessary build output.
if command -v mingw32-make >/dev/null 2>&1; then
    mingw32-make >/dev/null || exit 1
else
    make >/dev/null || exit 1
fi

# Locate the benchmark executable.
bin="./bench"

if [ ! -x "$bin" ] && [ -x "./bench.exe" ]; then
    bin="./bench.exe"
fi

if [ ! -x "$bin" ]; then
    echo "Error: bench executable not found."
    exit 1
fi

passed=0
failed=0

# Run one benchmark test and verify its expected output.
check() {
    local name="$1"
    local expected="$2"
    shift 2

    local output status ratio

    output=$("$bin" "$@" 2>&1)
    status=$?

    if [ "$status" -eq 0 ] && [[ "$output" == *"$expected"* ]]; then
        passed=$((passed + 1))

        if [[ "$name" == sort* ]]; then
            # Read the measured ratio from the benchmark output.
            ratio=$(printf '%s\n' "$output" |
                awk '/^Ratio:/ {print $2; exit}')

            printf 'PASS  %-35s Ratio: %s\n' \
                "$name" "${ratio:-N/A}"
        else
            printf 'PASS  %-35s Probes: OK\n' "$name"
        fi
    else
        printf 'FAIL  %s (status %d)\n' "$name" "$status"
        printf '%s\n' "$output"
        failed=$((failed + 1))
    fi
}

echo
echo "=== CMSC 131 Lab 2: Edge-Case Tests ==="

# Test sorting and searching with additional input files.
echo
echo "=== Sorting and Searching ==="

for file in tests/edge_cases/*.txt; do
    name=$(basename "$file")

    check "sort $name" "Match:       YES" \
        --sort "$file"

    check "search $name" "bsearch_asm: all probes correct" \
        --search "$file"
done

# Compile the independent C utility test harness.
echo
echo "=== GCD and Sum Range ==="
echo

exe="./edge_util_tests.exe"

# Remove the temporary executable when the script exits.
trap 'rm -f "$exe"' EXIT

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        gcc -m32 tests/edge_cases/test_util.c util.obj \
            -o "$exe" || exit 1
        ;;
    *)
        gcc -m32 -no-pie tests/edge_cases/test_util.c util.obj \
            -o "$exe" || exit 1
        ;;
esac

# Capture the utility results and exit status.
util_output=$("$exe" 2>&1)
util_status=$?

# Display the tables but leave out the original summary.
printf '%s\n' "$util_output" |
    sed -E '/^[0-9]+ passed, [0-9]+ failed\.$/d'

# Extract the utility test totals.
summary=$(printf '%s\n' "$util_output" | tail -n 1)

if [[ "$summary" =~ ^([0-9]+)\ passed,\ ([0-9]+)\ failed\.$ ]]; then
    util_passed=${BASH_REMATCH[1]}
    util_failed=${BASH_REMATCH[2]}
else
    echo "Error: Could not read utility test summary."
    exit 1
fi

# Calculate the combined results.
sort_total=$((passed + failed))
util_total=$((util_passed + util_failed))
total_passed=$((passed + util_passed))
total_checks=$((sort_total + util_total))

echo "----------------------------------------"
printf 'Sorting and Searching: %d/%d passed\n' \
    "$passed" "$sort_total"
printf 'GCD and Sum Range:      %d/%d passed\n' \
    "$util_passed" "$util_total"
echo "----------------------------------------"
printf 'Total:                  %d/%d passed\n' \
    "$total_passed" "$total_checks"
echo

# Return failure if any test failed.
if [ "$failed" -eq 0 ] &&
   [ "$util_failed" -eq 0 ] &&
   [ "$util_status" -eq 0 ]; then
    echo "All edge-case checks passed."
    exit 0
else
    echo "Some edge-case checks failed."
    exit 1
fi
