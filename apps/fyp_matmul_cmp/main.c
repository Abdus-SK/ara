// FYP: like-for-like matrix multiply, CVA6 alone (scalar C) vs Ara (vector kernels).
//
// Same simulated hardware (Ara SoC with the FYP CVA6, config cv64a6_imafdcv_sv39),
// same compiler and flags, same input matrices, same cycle timer (fence + csrr cycle),
// same method: each kernel runs once untimed (warm-up), then once timed.
// The scalar and vector results are compared element by element.
//
// Sizes: n x n times n x n, n = 4, 8, ... FYP_MAX_N (default 32).
// Build with a larger size: make -C apps bin/fyp_matmul_cmp ENV_DEFINES=-DFYP_MAX_N=64
// Simulated cycles: about 4 M for n <= 32 (about 20 min on the laptop at ~3.5 kHz);
// n = 64 adds about 12 M (about 1 h more); 128 adds about 100 M (many hours).
//
// Note: in this config CVA6 has an 8 KB data cache (the FYP base config cv64a6_imafdc_sv39
// has 32 KB), so the scalar numbers here are for the smaller-cache CVA6.

#include <stdint.h>

#include "kernel/scalar_kernels.h"
#include "../imatmul/kernel/imatmul.h"
#include "../fmatmul/kernel/fmatmul.h"
#include "runtime.h"
#include "util.h"

#ifdef SPIKE
#include <stdio.h>
#else
#include "printf.h"
#endif

#ifndef FYP_MAX_N
#define FYP_MAX_N 32
#endif
#define NN (FYP_MAX_N * FYP_MAX_N)

int64_t ia[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
int64_t ib[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
int64_t ic_s[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
int64_t ic_v[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
double fa[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
double fb[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
double fc_s[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));
double fc_v[NN] __attribute__((aligned(32 * NR_LANES), section(".l2")));

// Deterministic inputs (no data file): 64-bit LCG (Knuth MMIX constants).
static uint64_t lcg_state = 0x2026111700000001ULL;
static uint64_t lcg(void) {
  lcg_state = lcg_state * 6364136223846793005ULL + 1442695040888963407ULL;
  return lcg_state >> 11;
}

static void init_inputs(void) {
  for (unsigned long i = 0; i < NN; ++i) {
    // Integers in [-1000, 1000]: no overflow (|sum| <= 128 * 1e6).
    ia[i] = (int64_t)(lcg() % 2001) - 1000;
    ib[i] = (int64_t)(lcg() % 2001) - 1000;
    // Doubles in [-1, 1).
    fa[i] = (double)(lcg() & ((1ULL << 52) - 1)) / (double)(1ULL << 51) - 1.0;
    fb[i] = (double)(lcg() & ((1ULL << 52) - 1)) / (double)(1ULL << 51) - 1.0;
  }
}

static double fabs_d(double x) { return x < 0 ? -x : x; }

// No instruction count: reading instret or minstret traps (illegal instruction) in this
// Ara build of CVA6, while the cycle counter works (seen 2026-11-17, not explained yet).

static int64_t time_imatmul(int vector, unsigned long n) {
  int64_t *c = vector ? ic_v : ic_s;
  for (int run = 0; run < 2; ++run) {  // run 0: warm-up, run 1: timed
    start_timer();
    if (vector) imatmul(c, ia, ib, n, n, n);
    else scalar_imatmul(c, ia, ib, n, n, n);
    stop_timer();
  }
  return get_timer();
}

static int64_t time_fmatmul(int vector, unsigned long n) {
  double *c = vector ? fc_v : fc_s;
  for (int run = 0; run < 2; ++run) {
    start_timer();
    if (vector) fmatmul(c, fa, fb, n, n, n);
    else scalar_fmatmul(c, fa, fb, n, n, n);
    stop_timer();
  }
  return get_timer();
}

// Prints one table row; returns the number of elements that do not match.
static int report(const char *type, unsigned long n, int64_t ts, int64_t tv,
                  long mismatches, double max_rel) {
  double macs = (double)n * n * n;
  double speedup = (double)ts / (double)tv;
  double util = 100.0 * (2.0 * macs / (double)tv) / (2.0 * NR_LANES);
  printf("%s n=%3lu  scalar %9ld cyc (%6.2f cyc/MAC)  vector %8ld cyc (%5.1f%% util)  "
         "speedup %7.2fx  check %s",
         type, n, (long)ts, (double)ts / macs, (long)tv, util, speedup,
         mismatches ? "FAIL" : "ok");
  // Ara's printf has no %e: print the relative difference in units of 1e-15.
  if (max_rel >= 0) printf(" (max rel diff %.3f e-15)", max_rel * 1e15);
  printf("\n");
  return (int)mismatches;
}

int main() {
  int errors = 0;
  printf("\n=== FYP matmul: CVA6 scalar vs Ara vector (NR_LANES=%d, VLEN=%d, max n=%d) ===\n",
         NR_LANES, VLEN, FYP_MAX_N);
  printf("Warm-up run, then timed run (cycle counter, fence first).\n");
  printf("cyc/MAC = scalar cycles / n^3; util = vector OP/cycle / (2*NR_LANES).\n");
  init_inputs();

  for (unsigned long n = 4; n <= FYP_MAX_N; n *= 2) {
    int64_t ts = time_imatmul(0, n);
    int64_t tv = time_imatmul(1, n);
    long bad = 0;
    for (unsigned long i = 0; i < n * n; ++i)
      if (ic_s[i] != ic_v[i]) ++bad;
    errors += report("int64", n, ts, tv, bad, -1.0);
  }

  for (unsigned long n = 4; n <= FYP_MAX_N; n *= 2) {
    int64_t ts = time_fmatmul(0, n);
    int64_t tv = time_fmatmul(1, n);
    long bad = 0;
    double max_rel = 0.0;
    for (unsigned long i = 0; i < n * n; ++i) {
      double d = fabs_d(fc_s[i] - fc_v[i]);
      double m = fabs_d(fc_s[i]) > 1e-300 ? fabs_d(fc_s[i]) : 1e-300;
      if (d / m > max_rel) max_rel = d / m;
      if (d > 1e-12 * m + 1e-15) ++bad;
    }
    errors += report("fp64 ", n, ts, tv, bad, max_rel);
  }

  printf("=== %s: %d mismatching elements ===\n", errors ? "FAILED" : "PASSED", errors);
  return errors;
}
