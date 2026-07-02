# xxh64

A fast, portable, high-quality non-cryptographic hash for MoonBit — a faithful
port of **XXH64** from the reference [xxHash](https://github.com/Cyan4973/xxHash)
by Yann Collet. 64-bit output, little-endian, seedable.

## Why XXH64

XXH64 uses only 64×64 → **low 64** multiplies (a single `mul`), so unlike
rapidhash / wyhash / xxh3, it needs no "multiply-high" (`umulh` / `__int128`)
primitive. That makes it map cleanly onto MoonBit's `UInt64` with no
portable-schoolbook emulation penalty, and it runs at the same speed on every
backend (native / wasm / js). It passes SMHasher and is widely deployed.

## Install

```bash
moon add tonyfettes/xxh64
```

Then import it in your package's `moon.pkg`:

```
import { "tonyfettes/xxh64" }
```

## Usage

```mbt check
///|
test {
  // 64-bit hash of a byte buffer.
  let h = @xxh64.xxh64(b"abc")
  inspect(@xxh64.to_hex(h), content="44bc2cf5ad770999")

  // A seed perturbs the result deterministically.
  inspect(h == @xxh64.xxh64(b"abc", seed=1), content="false")
}
```

## API

```
fn xxh64(Bytes, seed? : UInt64) -> UInt64
fn to_hex(UInt64) -> String
```

Output is bit-for-bit identical to the reference C `XXH64`, validated against
reference-generated known-answer vectors (see `xxh64_test.mbt`).

## Benchmark

Run with `moon run --release --target <backend> bench/moon_bench`. Results below
are from an Apple M1 Pro.

### native

| size (bytes) | best GB/s | avg GB/s | best ns/hash |
|-------------:|----------:|---------:|-------------:|
| 16 | 4.715 | 3.953 | 3.4 |
| 64 | 9.149 | 8.780 | 7.0 |
| 240 | 15.307 | 14.959 | 15.7 |
| 1,024 | 17.230 | 17.182 | 59.4 |
| 65,536 | 17.765 | 17.721 | 3,689.1 |
| 1,048,576 | 17.616 | 17.606 | 59,523.3 |

### wasm

| size (bytes) | best GB/s | avg GB/s | best ns/hash |
|-------------:|----------:|---------:|-------------:|
| 16 | 1.956 | 1.836 | 8.2 |
| 64 | 5.257 | 5.188 | 12.2 |
| 240 | 9.717 | 9.512 | 24.7 |
| 1,024 | 12.789 | 12.639 | 80.1 |
| 65,536 | 13.594 | 13.468 | 4,820.8 |
| 1,048,576 | 13.265 | 13.112 | 79,045.5 |

### wasm-gc

| size (bytes) | best GB/s | avg GB/s | best ns/hash |
|-------------:|----------:|---------:|-------------:|
| 16 | 1.391 | 1.382 | 11.5 |
| 64 | 1.397 | 1.388 | 45.8 |
| 240 | 1.584 | 1.578 | 151.5 |
| 1,024 | 1.667 | 1.665 | 614.3 |
| 65,536 | 1.696 | 1.692 | 38,646.5 |
| 1,048,576 | 1.698 | 1.695 | 617,562.4 |

### Reference C (Apple clang -O3, Apple M1 Pro)

Run with `make -C bench run-native`. Compares the reference C implementations of
XXH64, XXH3, and rapidhash on identical input:

| size (bytes) | XXH64 GB/s | XXH3 GB/s | rapidhash GB/s |
|-------------:|-----------:|----------:|---------------:|
| 16 | 6.470 | 11.604 | 11.664 |
| 64 | 11.505 | 21.925 | 29.187 |
| 240 | 16.274 | 27.435 | 41.756 |
| 1,024 | 16.817 | 42.042 | 51.090 |
| 102,400 | 16.578 | 43.098 | 56.400 |
| 1,048,576 | 16.629 | 43.593 | 54.570 |

The MoonBit **native** backend with `--release` achieves ~17.6 GB/s on large
inputs — matching the reference C XXH64 (~16.6 GB/s). The **wasm** backend
reaches ~13.3 GB/s and **wasm-gc** ~1.7 GB/s. For comparison, reference C XXH3
(which uses wide `__int128` multiplies) reaches ~43.6 GB/s on the same hardware.

## Profiling: why wasm is slower than native

Install [moon-pprof](https://github.com/mizchi/moon-pprof) (`cargo install moon-pprof --locked`,
requires `wasmtime`) then profile the tight-loop binary:

```sh
moon build --debug --target wasm bench/wasm_profile
moon-pprof profile _build/wasm/debug/build/bench/wasm_profile/wasm_profile.wasm \
  --out /tmp/xxh64.pb.gz
moon-pprof summary /tmp/xxh64.pb.gz
```

### Key findings

1. **Function-call overhead is the dominant cost in WASM**.  The MoonBit WASM
   backend does *not* inline tiny helper functions — even a 3-instruction
   `read64(data, p)` remains a separate `call` in release builds.  Each `call`
   instruction costs a pipeline flush on the WASM engine.  The original code
   had 8 calls per 32-byte stripe (4 × `read64` + 4 × `round`).  Manually
   inlining both into the loop body eliminated those calls, yielding a
   **2.5× speedup** on WASM release builds (5.4 → 13.3 GB/s).

2. **Cannot use V128 to accelerate reads**.  MoonBit's `core/v128` module
   exposes 227 SIMD lane operations (`i64x2_extract_lane`, `i64x2_mul`, …)
   but **does not expose `v128.load` / `v128.store`**.  There is no way to
   construct a V128 from a `Bytes` buffer.  If `v128.load` were available, it
   would halve the number of bounds-checked loads per stripe (2 × v128.load
   instead of 4 × i64.load).

3. **WASM linear-memory bounds checks remain**.  Even the lowest-level
   `Bytes::unsafe_read_uint64_le` compiles to a single `i64.load` — but in
   WASM every `i64.load` carries an implicit bounds check.  On native, the
   compiler hoists the bounds check out of the loop and emits a single `ldr`
   instruction per read.  This is a fundamental WASM spec constraint that
   cannot be worked around at the source level.

### Optimisation applied

The original code called helpers from the hot loop:

```mbt nocheck
// Before — ~5.4 GB/s on wasm
while p <= limit {
  a1 = round(a1, read64(data, p))
  a2 = round(a2, read64(data, p + 8))
  // ...
}
```

After inlining `read64` and `round` directly:

```mbt nocheck
// After — ~13.3 GB/s on wasm
while p <= limit {
  a1 = rotl(a1 + data.unsafe_read_uint64_le(p) * P2, 31) * P1
  a2 = rotl(a2 + data.unsafe_read_uint64_le(p + 8) * P2, 31) * P1
  // ...
}
```

This removes 8 `call` instructions per 32-byte stripe. The native backend
already inlines these tiny functions automatically, so it sees no change.

## License

BSD-2-Clause. Based on xxHash (Yann Collet), also BSD-2-Clause. See `LICENSE`.
