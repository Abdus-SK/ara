// FYP: plain C matrix multiply, C = A * B, row-major, A = M x N, B = N x P, C = M x P.
// Runs on CVA6 alone (no vector instructions).
#ifndef FYP_SCALAR_KERNELS_H
#define FYP_SCALAR_KERNELS_H
#include <stdint.h>

void scalar_imatmul(int64_t *c, const int64_t *a, const int64_t *b,
                    unsigned long M, unsigned long N, unsigned long P);
void scalar_fmatmul(double *c, const double *a, const double *b,
                    unsigned long M, unsigned long N, unsigned long P);
#endif
