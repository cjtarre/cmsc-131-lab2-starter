<!--no-pdf-->
# CMSC 131 Lab 2 Starter

[![lab2-checks](https://github.com/WhiteLicorice/cmsc-131-lab2-starter/actions/workflows/test.yml/badge.svg)](https://github.com/WhiteLicorice/cmsc-131-lab2-starter/actions/workflows/test.yml)

A C-callable library of sort, search, and utility routines in assembly. The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile       platform preamble and build rules
bench.c        provided: file I/O, timing, the C-side comparison, the hostile caller
cdecl.h        provided: the calling-convention macros
LICENSE        provided
sort.asm       yours
search.asm     yours
util.asm       yours
run_tests.sh   provided: the correctness gate
tests/         provided: the test corpus
```

## What to Run

On Windows, run these commands in Git Bash, the shell from Block 1. In that
shell, `make` is your alias for `mingw32-make`. On Linux, use your terminal.

```bash
make
make check
```

`make` builds `bench`. `make check` builds, then runs `./run_tests.sh`,
which reports each check and exits nonzero when any of them fail. Each run
is captured first. Its exit status is read before its text is examined,
so a program that prints the right line and then crashes still fails.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, and 19
of the 36 checks fail. The seventeen that pass prove little. Four are files
that arrive empty, single-element, or already sorted. `gcd(0, 0)` expects 0.
The hostile caller cannot be upset by a stub that touches no register. The
rest are argument and file refusals that the harness performs before any
assembly runs. That red run is the correct starting state for a starter. The
badge stays red until you implement the routines.

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `bench.c`, `Makefile`, `run_tests.sh`, or a `tests/`
file appears as a diff in the open.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

---

## Design Notes

Complete this section before the Week 1 progress report and finish it by Week 3. The syllabus asks for problem analysis, a solution architecture, and an estimated timeline. The manual's Deliverables section lists what this activity adds. Keep each part short. Update it when the plan changes.

### Problem analysis

The four routines `bench.c` expects and what each one returns. Which
registers you preserve and why.

- **`qsort_asm`:** `void qsort_asm(int *arr, int n)` sorts an array of signed 32-bit integers in ascending order in place and does not return a value. It serves as the C-facing entry point and calls an internal recursive quicksort routine using explicit `lo` and `hi` bounds. The routine uses Lomuto partitioning, with the last element of the current range as the pivot. After partitioning, the routine recursively sorts the ranges before and after the pivot.

- **`bsearch_asm`:** `int bsearch_asm(int *arr, int n, int key)` runs a recursive binary search on a sorted array of signed ints. It returns 0-based index of `key` in `eax`, or `-1` if the key isn't found in the array. The midpoint is computed as `lo + (hi - lo) / 2` rather than just `(lo + hi) / 2`, because the sum `lo+hi` can overflow 32 bits for very large indices, while `hi - lo` never exceeds the array size. The base case is `lo > hi`, which returns `-1` and also covers the empty array (`n=0`).

- **gcd_asm:** `int gcd_asm(int a, int b)` runs a recursive Euclid algorithm to calculate the greatest common divisor of two nonnegative integers. It keeps track of the total recursive depth with an exported global variable `gcd_depth`, whose value is updated whenever the function's internal counter `curr_depth` exceeds `gcd_depth`'s stored value. `curr_depth` increments by `1` on routine entry and decrements by `1` before returning. `gcd_depth` is reset to `0` on every new top-level C harness call. 
    - `gcd_asm(a, b)`: returns GCD of `a` and `b`
    - `gcd_asm(a, 0)`: returns `a`
    - `gcd_asm(0, b)`: returns `b`
    - `gcd_asm(0, 0)`: returns `0`

- **`sum_range_asm`:** `int sum_range_asm(int lo, int hi)` returns the inclusive sum in `eax`. The hard part is reentrancy: bench calls `bench_callback()` once per call from C, and that callback starts a second `sum_range_asm` before the first finishes. Both must return correct sums (500500 and 5050), so no state can live in a global.

Under the cdecl calling convention, `eax`, `ecx`, and `edx` are caller-saved registers, while `ebx`, `esi`, `edi`, and `ebp` are callee-saved. Any callee-saved register modified by a routine must be restored before returning so the caller's values are preserved. Return values are placed in `eax`.

### Solution architecture

A stack frame diagram for one recursive call of `qsort_asm`, showing where the arguments, the return address, saved `ebp`, and the saved registers sit. Why `sum_range_asm` is reentrant.

#### Stack frame of a recursive quicksort call

`qsort_asm` serves as the C-facing entry point for sorting and calls an internal recursive quicksort routine using explicit `lo` and `hi` bounds. The recursive routine stops when `lo >= hi`. Otherwise, it partitions the current range using the Lomuto partition scheme, then recursively sorts the ranges `lo` to `p - 1` and `p + 1` to `hi`, where `p` is the pivot position returned by the partition routine.

```text
Higher addresses
[ebp+16]  hi
[ebp+12]  lo
[ebp+8]   array base
[ebp+4]   return address
[ebp]     saved ebp
           saved registers / local values
Lower addresses
```

The exact saved registers and local values will be updated once the final implementation is complete. Any callee-saved registers used by the routine must be restored before returning.

#### Reentrancy of `sum_range_asm`

- **Why sum_range_asm is reentrant:** It keeps no globals. `lo` and `hi` live in the call's own stack frame (`[ebp+8]`, `[ebp+12]`) and the running total lives in a register or that frame, so the nested call from `bench_callback()` gets its own frame and can't touch the outer call's values. The callback runs once at entry, before any live value is held in `eax`, `ecx` or `edx`.

### Measurements

The ratio `bench` reports on `random1000.txt`, `sorted1000.txt`,
`reverse1000.txt`, `duplicates.txt`, and `identical.txt`. Your worst case and its cause. One improvement and its estimated effect.

| File | Ratio |
|---|---|
| `random1000.txt` | |
| `sorted1000.txt` | |
| `reverse1000.txt` | |
| `duplicates.txt` | |
| `identical.txt` | |

### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

| Week | Goal | Owner |
|---|---|---|
| 1 | Repository setup, Design Notes, subsystem ownership, and working prototype | All members |
| 2 | Complete Sorting and Searching subsystems | Ma. Christie Jude Tarre; Trisha Mae Hechenagocia & Gabrielle Sumergido |
| 3 | Complete Convention and measurement, testing, benchmarks, and documentation | Aleighia Keith L. Reyes; All members for testing and documentation |
| 4 | Defense | All members |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists the three subsystems. Each member owns one. In a group of four, two members share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---| 
| Sorting (`qsort_asm` and its partition) | Ma. Christie Jude Tarre |
| Searching (`bsearch_asm`, `gcd_asm`) | Trisha Mae Hechenagocia & Gabrielle Sumergido |
| Convention and measurement (`sum_range_asm`, the benchmarks) | Aleighia Keith L. Reyes |

## Quirks and Issues

Complete this section before the Week 3 progress report. The syllabus asks for documentation of quirks and issues with the complete implementation. One entry per item. State what happens, what causes it, and what the group did about it.

### Known issues

- 

### Quirks

- 
