# Optimized Arbitrary-Precision Square Root

This assembly x86-64 project implements an **iterative, bit-level algorithm** to compute the integer square root of a non-negative number `X` **up to 256 000 bits**  represented in binary form across multiple 64-bit words. For a given `2n`-bit input `X`, the algorithm computes an `n`-bit integer `Q` so that `Q^2 ≤ X < (Q+1)^2`.
The program is focused on precise low-level arithmetic such as bit shifts, subtraction and borrow handling.
Robustly handles edge cases and is designed for performance, compact size, correctness, and memory safety.

## The implementation is exposed as a C-callable assembly function:

```c
void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);
```

X and Q are arrays of uint64_t storing the numbers in little-endian binary form.

n is the number of bits of the resulting square root (must be divisible by 64).

X is used as temporary workspace for intermediate calculations.

## Algorithm Overview

The algorithm iteratively determines each bit of Q starting from the most significant bit:

1. Initialization:
  
     - Q0 = 0 (initial result) and R0 = X (remainder)
  
2. Bitwise Iteration (for j = 1 … n):
    - Compute the trial value:
    `T_{j-1} = 2^(n-j+1) * Q_{j-1} + 2^(2(n-j))`

    - Compare R_{j-1} with T_{j-1}:

          If `R_{j-1} ≥ T_{j-1}`, set `q_j = 1` and `R_j = R_{j-1} - T_{j-1}`
    
          Otherwise, set `q_j = 0` and `R_j = R_{j-1}`
  
3. Final Result:
After n iterations, `Q = ∑ q_j 2^(n-j)` and the remainder `R_n = X - Q^2` satisfies `0 ≤ R_n < 2Q`.


