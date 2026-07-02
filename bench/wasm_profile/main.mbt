///|
fn bench_input(len : Int, seed : Int) -> Bytes {
  Bytes::makei(len, fn(i) { ((i * 131 + seed * 17 + 17) & 0xff).to_byte() })
}

///|
fn main {
  // Run xxh64 in a tight loop so the profiler sees only the hash code
  let data = bench_input(1048576, 0)
  let mut acc = 0UL
  for _ in 0..<1024 {
    acc = acc + @xxh64.xxh64(data)
  }
  // Prevent dead-code elimination
  println(@xxh64.to_hex(acc))
}
