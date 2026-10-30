///|
fn bench_input(len : Int32, variant : Int32) -> Bytes {
  Bytes::from_array(
    FixedArray::makei(len, i => ((i * 131 + variant * 17 + 17) & 0xff).to_byte())[:],
  )
}

///|
fn to_double(value : Int32) -> Double {
  value.to_int64().to_double()
}

///|
fn run_case(size : Int32, iters : Int32, reps : Int32) -> UInt64 {
  let inputs : FixedArray[Bytes] = FixedArray::makei(16, variant => {
    bench_input(size, variant)
  })
  let warmup = if iters < 1000 { iters } else { 1000 }
  let mut checksum = 0UL
  for i in 0..<warmup {
    checksum = checksum + @xxh64.xxh64(inputs.unsafe_get(i & 15))
  }
  let mut best_us = 1.0e100
  let mut sum_us = 0.0
  for _ in 0..<reps {
    let start = @bench.monotonic_clock_start()
    for i in 0..<iters {
      checksum = checksum + @xxh64.xxh64(inputs.unsafe_get(i & 15))
    }
    let elapsed_us = @bench.monotonic_clock_end(start)
    if elapsed_us < best_us {
      best_us = elapsed_us
    }
    sum_us = sum_us + elapsed_us
  }
  let bytes = to_double(size) * to_double(iters)
  let avg_us = sum_us / to_double(reps)
  let best_gbps = bytes / best_us / 1000.0
  let avg_gbps = bytes / avg_us / 1000.0
  let best_ns_per_hash = best_us * 1000.0 / to_double(iters)
  println(
    "\{size},\{iters},\{reps},\{best_gbps},\{avg_gbps},\{best_ns_per_hash},\{@xxh64.to_hex(checksum)}",
  )
  checksum
}

///|
fn main {
  println("size,iters,reps,best_GBps,avg_GBps,best_ns_per_hash,checksum")
  let mut checksum = 0UL
  checksum = checksum + run_case(16, 5_000_000, 3)
  checksum = checksum + run_case(64, 2_000_000, 3)
  checksum = checksum + run_case(240, 1_000_000, 3)
  checksum = checksum + run_case(1024, 500_000, 3)
  checksum = checksum + run_case(65536, 16_384, 3)
  checksum = checksum + run_case(1048576, 1024, 3)
  println("total_checksum,\{@xxh64.to_hex(checksum)}")
}
