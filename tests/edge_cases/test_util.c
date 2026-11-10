/*
 * Additional utility tests for CMSC 131 Lab 2.
 * Tests gcd_asm, sum_range_asm, and reentrancy.
 * Does not modify the provided bench.c.
 */

#include <limits.h>
#include <stdio.h>

/* Assembly routines and shared recursion-depth counter. */
extern int gcd_asm(int a, int b);
extern int sum_range_asm(int lo, int hi);
extern int gcd_depth;

/* Expected behavior for the nested sum-range call. */
#define EXPECTED_NESTED_SUM 9
#define EXPECTED_CALLBACKS 2

/* Track passed and failed utility tests. */
static int passed = 0;
static int failed = 0;

/* Track callbacks and the nested call result. */
static int callback_count = 0;
static int nested_started = 0;
static int nested_result = 0;

/*
 * The assembly routine calls this callback.
 * The first invocation starts a nested sum_range_asm call
 * to test whether the routine is reentrant.
 */
void bench_callback(void) {
    callback_count++;

    if (!nested_started) {
        nested_started = 1;
        nested_result = sum_range_asm(2, 4);
    }
}

/* Record the result and return its display label. */
static const char *record_result(int correct) {
    if (correct) {
        passed++;
        return "PASS";
    }

    failed++;
    return "FAIL";
}

/*
 * Test the GCD result and maximum recursion depth.
 * Display results using actual/expected notation.
 */
static void test_gcd(
    const char *name,
    int a,
    int b,
    int expected,
    int expected_depth
) {
    int result = gcd_asm(a, b);
    int depth = gcd_depth;

    int correct = (
        result == expected &&
        depth == expected_depth
    );

    /* Prepare the values for aligned terminal columns. */
    char gcd_values[32];
    char depth_values[32];

    snprintf(gcd_values, sizeof(gcd_values),
             "%d/%d", result, expected);

    snprintf(depth_values, sizeof(depth_values),
             "%d/%d", depth, expected_depth);

    printf("%-6s %-38s %-13s %s\n",
           record_result(correct),
           name,
           gcd_values,
           depth_values);
}

/*
 * Test sum_range_asm and its reentrancy behavior.
 * Each test checks:
 *   1. The returned sum.
 *   2. The nested sum_range_asm result.
 *   3. The number of callback invocations.
 */
static void test_sum(
    const char *name,
    int lo,
    int hi,
    int expected
) {
    /* Reset the callback state before each test. */
    callback_count = 0;
    nested_started = 0;
    nested_result = INT_MIN;

    int result = sum_range_asm(lo, hi);

    int correct = (
        result == expected &&
        nested_result == EXPECTED_NESTED_SUM &&
        callback_count == EXPECTED_CALLBACKS
    );

    /* Prepare the values for aligned terminal columns. */
    char sum_values[32];
    char nested_values[32];
    char callback_values[32];

    snprintf(sum_values, sizeof(sum_values),
             "%d/%d", result, expected);

    snprintf(nested_values, sizeof(nested_values),
             "%d/%d", nested_result, EXPECTED_NESTED_SUM);

    snprintf(callback_values, sizeof(callback_values),
             "%d/%d", callback_count, EXPECTED_CALLBACKS);

    printf("%-6s %-38s %-12s %-12s %s\n",
           record_result(correct),
           name,
           sum_values,
           nested_values,
           callback_values);
}

int main(void) {
    /*
     * GCD tests:
     * Equal operands, smaller first operand, large values,
     * deep recursion, and recursion-depth reset.
     */
    printf("GCD (actual/expected)\n");
    printf("%-6s %-38s %-13s %s\n",
           "STATUS", "TEST", "GCD", "DEPTH");

    test_gcd("gcd equal operands", 42, 42, 42, 2);
    test_gcd("gcd smaller first operand", 35, 64, 1, 7);
    test_gcd("gcd large integers", 2147483647, 2147483646, 1, 3);
    test_gcd("gcd deep recursion", 1836311903, 1134903170, 1, 45);
    test_gcd("gcd depth reset after deep recursion", 17, 0, 17, 1);

    /*
     * Sum Range tests:
     * Single-element, empty, zero-crossing, negative-only,
     * and positive ranges.
     *
     * Every test also checks nested calls and callbacks.
     */
    printf("\nSUM RANGE (actual/expected)\n");
    printf("%-6s %-38s %-12s %-12s %s\n",
           "STATUS", "TEST", "SUM", "NESTED", "CALLBACKS");

    test_sum("sum single element", 5, 5, 5);
    test_sum("sum empty range", 10, 5, 0);
    test_sum("sum across zero", -3, 3, 0);
    test_sum("sum negative-only range", -5, -1, -15);
    test_sum("sum positive range", 1, 100, 5050);

    /* Keep this summary for the automated test runner. */
    printf("\n%d passed, %d failed.\n", passed, failed);

    return failed == 0 ? 0 : 1;
}
