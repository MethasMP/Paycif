# Bolt's Performance Journal

## 2026-07-26 - [DSP Optimization via Complex Arithmetic Elimination]
**Learning:** In Go, standard library `math/cmplx` operations (such as `cmplx.Exp`) introduce function call and struct construction overhead. When the complex operation is in a hot loop and has a constant real value of 0 (e.g. $e^{-i\theta}$), using Euler's formula $e^{-i\theta} = \cos(\theta) - i\sin(\theta)$ allows us to split the computation into raw `float64` real/imaginary parts.
Additionally, using Go's `math.Sincos(angle)` is highly optimized (often utilizing a single hardware instruction) and is significantly faster than calculating sine and cosine separately.
Finally, by folding on-the-fly transformations (like subtraction of means) directly into the inner loop, we can eliminate buffer/slice allocations completely (reducing allocations from 1 to 0 and B/op from 1024 to 0), avoiding any GC overhead.

**Action:** Whenever implementing or optimizing Fourier Transforms (DFT/FFT) or signal processing logic in Go, avoid using the `math/cmplx` library. Instead, manually accumulate the real and imaginary parts using `math.Sincos` and avoid pre-allocating slices for intermediate states if values can be derived mathematically on-the-fly.
