// FYP: plain C matrix multiply for CVA6 alone.
// The compiler flags already forbid vector code (-fno-vectorize, -mllvm
// -scalable-vectorization=off, -riscv-v-vector-bits-min=0); the pragmas make it explicit.
// The k loop is innermost and accumulates in a register, like the scalar 8x8 baseline
// in the CVA6 fork. fmatmul accumulates in the same k order (with fused multiply-add).
#include "scalar_kernels.h"

__attribute__((noinline)) void scalar_imatmul(int64_t *c, const int64_t *a,
                                              const int64_t *b, unsigned long M,
                                              unsigned long N, unsigned long P) {
  for (unsigned long i = 0; i < M; ++i) {
    for (unsigned long j = 0; j < P; ++j) {
      int64_t acc = 0;
#pragma clang loop vectorize(disable) interleave(disable)
      for (unsigned long k = 0; k < N; ++k)
        acc += a[i * N + k] * b[k * P + j];
      c[i * P + j] = acc;
    }
  }
}

__attribute__((noinline)) void scalar_fmatmul(double *c, const double *a,
                                              const double *b, unsigned long M,
                                              unsigned long N, unsigned long P) {
  for (unsigned long i = 0; i < M; ++i) {
    for (unsigned long j = 0; j < P; ++j) {
      double acc = 0.0;
#pragma clang loop vectorize(disable) interleave(disable)
      for (unsigned long k = 0; k < N; ++k)
        acc += a[i * N + k] * b[k * P + j];
      c[i * P + j] = acc;
    }
  }
}
