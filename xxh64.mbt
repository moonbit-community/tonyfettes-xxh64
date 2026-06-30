// XXH64 — a faithful MoonBit port of the reference C (Cyan4973/xxHash).
//
// Unlike rapidhash/wyhash/xxh3, XXH64 never needs the high 64 bits of a
// 64×64 product: every multiply is 64×64 → low 64 (a single `mul`), so it maps
// directly onto MoonBit's `UInt64::*` with no `umulh` / `__int128` dependency
// and no portable-schoolbook penalty. 64-bit output, little-endian reads.
// Validated against reference-generated known-answer vectors (see the tests).

///|
const P1 : UInt64 = 0x9E3779B185EBCA87UL

///|
const P2 : UInt64 = 0xC2B2AE3D27D4EB4FUL

///|
const P3 : UInt64 = 0x165667B19E3779F9UL

///|
const P4 : UInt64 = 0x85EBCA77C2B2AE63UL

///|
const P5 : UInt64 = 0x27D4EB2F165667C5UL

///|
/// Rotate-left by `r` (1..63).
fn rotl(x : UInt64, r : Int) -> UInt64 {
  (x << r) | (x >> (64 - r))
}

///|
/// `XXH64_round`: fold one 64-bit lane into an accumulator.
fn round(acc : UInt64, input : UInt64) -> UInt64 {
  rotl(acc + input * P2, 31) * P1
}

///|
/// `XXH64_mergeRound`: combine a finished lane into the running hash.
fn merge_round(acc : UInt64, val : UInt64) -> UInt64 {
  (acc ^ round(0, val)) * P1 + P4
}

///|
/// `XXH64_avalanche`: final bit-mixing.
fn avalanche(h : UInt64) -> UInt64 {
  let h = h ^ (h >> 33)
  let h = h * P2
  let h = h ^ (h >> 29)
  let h = h * P3
  h ^ (h >> 32)
}

///|
fn read64(data : Bytes, p : Int) -> UInt64 {
  data.unsafe_read_uint64_le(p)
}

///|
fn read32(data : Bytes, p : Int) -> UInt64 {
  data.unsafe_read_uint32_le(p).to_uint64()
}

///|
/// XXH64 of `data` with an optional `seed` (default 0). 64-bit output.
///
/// ```mbt nocheck
/// inspect(@xxh64.to_hex(@xxh64.xxh64(b"abc")), content="44bc2cf5ad770999")
/// ```
pub fn xxh64(data : Bytes, seed? : UInt64 = 0) -> UInt64 {
  let len = data.length()
  let mut p = 0
  let mut h = if len >= 32 {
    // Four parallel accumulator lanes over 32-byte stripes.
    let mut a1 = seed + P1 + P2
    let mut a2 = seed + P2
    let mut a3 = seed
    let mut a4 = seed - P1
    let limit = len - 32
    while p <= limit {
      a1 = round(a1, read64(data, p))
      a2 = round(a2, read64(data, p + 8))
      a3 = round(a3, read64(data, p + 16))
      a4 = round(a4, read64(data, p + 24))
      p = p + 32
    }
    let acc = rotl(a1, 1) + rotl(a2, 7) + rotl(a3, 12) + rotl(a4, 18)
    merge_round(merge_round(merge_round(merge_round(acc, a1), a2), a3), a4)
  } else {
    seed + P5
  }
  h = h + len.to_uint64()
  // Finalize the trailing 0..31 bytes: 8-byte, then 4-byte, then 1-byte chunks.
  let mut rem = len - p
  while rem >= 8 {
    h = h ^ round(0, read64(data, p))
    h = rotl(h, 27) * P1 + P4
    p = p + 8
    rem = rem - 8
  }
  if rem >= 4 {
    h = h ^ (read32(data, p) * P1)
    h = rotl(h, 23) * P2 + P3
    p = p + 4
    rem = rem - 4
  }
  while rem > 0 {
    h = h ^ (data.unsafe_get(p).to_uint64() * P5)
    h = rotl(h, 11) * P1
    p = p + 1
    rem = rem - 1
  }
  avalanche(h)
}

///|
/// `xxh64` formatted as 16 lowercase hex chars.
///
/// ```mbt nocheck
/// inspect(@xxh64.to_hex(@xxh64.xxh64(b"abc")), content="44bc2cf5ad770999")
/// ```
pub fn to_hex(hash : UInt64) -> String {
  let hexchars = "0123456789abcdef".to_array()
  let buf = StringBuilder::new()
  for k in 0..<16 {
    buf.write_char(hexchars[((hash >> ((15 - k) * 4)) & 0xF).to_int()])
  }
  buf.to_string()
}
