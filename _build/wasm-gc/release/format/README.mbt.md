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

## License

BSD-2-Clause. Based on xxHash (Yann Collet), also BSD-2-Clause. See `LICENSE`.
