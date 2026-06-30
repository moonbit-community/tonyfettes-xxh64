// Known-answer vectors generated from the reference C (XXH64, seed 0,
// little-endian). Inputs are byte buffers `[0,1,…,n-1] (mod 256)`, with `n`
// chosen to exercise the <32 path, the 32-byte stripe loop, and every
// finalize chunk (8/4/1-byte tails).

///|
fn buf(n : Int) -> Bytes {
  Bytes::makei(n, fn(i) { (i % 256).to_byte() })
}

///|
test "XXH64 known-answer vectors (vs reference C)" {
  let cases : Array[(Int, String)] = [
    (0, "ef46db3751d8e999"),
    (1, "e934a84adb052768"),
    (2, "4865a00ba85b7cd6"),
    (3, "e5c7bb4533bc65dd"),
    (4, "ffced8604453cc1e"),
    (7, "14cc643f630c72d2"),
    (8, "884a173614b81b8d"),
    (9, "67d85784a7c78c5b"),
    (15, "a948f5f0f6abac2d"),
    (16, "44b6ef2fb84169f7"),
    (17, "5603e60c527599b6"),
    (31, "c346d2b59b4d8ee1"),
    (32, "cbf59c5116ff32b4"),
    (33, "0c535d1acafb8ead"),
    (48, "8fe437632da06964"),
    (64, "f7c67301db6713f0"),
    (80, "babc069ffd7e24b3"),
    (96, "450baa11f6739216"),
    (112, "f9a92625d5b4bccd"),
    (113, "e58ac015be9ad564"),
    (127, "464d085810ce0199"),
    (128, "7a7fe14647b9ab92"),
    (224, "faa428b31e3b7e8c"),
    (225, "3fd27c2a9639e043"),
    (256, "1facbe8406cd904b"),
  ]
  for c in cases {
    let (n, expected) = c
    assert_eq(@xxh64.to_hex(@xxh64.xxh64(buf(n))), expected)
  }
  assert_eq(@xxh64.to_hex(@xxh64.xxh64(b"abc")), "44bc2cf5ad770999")
}

///|
test "XXH64 seed perturbs the result deterministically" {
  assert_eq(
    @xxh64.to_hex(@xxh64.xxh64(buf(32), seed=0x9E3779B185EBCA87)),
    "bfb3e4ef6096c49c",
  )
  assert_not_eq(@xxh64.xxh64(buf(32)), @xxh64.xxh64(buf(32), seed=1))
}
