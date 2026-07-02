#define _DARWIN_C_SOURCE

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define XXH_INLINE_ALL
#include "xxhash.h"
#include "rapidhash.h"

typedef uint64_t (*hash_fn)(const void*, size_t);

static volatile uint64_t sink;

static uint64_t wrap_rapid(const void* p, size_t n) {
    return rapidhash(p, n);
}

static uint64_t wrap_xxh3(const void* p, size_t n) {
    return XXH3_64bits(p, n);
}

static uint64_t wrap_xxh64(const void* p, size_t n) {
    return XXH64(p, n, 0);
}

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static void compiler_memory_barrier(void) {
    __asm__ __volatile__("" ::: "memory");
}

static uint64_t run_loop(hash_fn fn, const unsigned char* data, size_t size, size_t iters) {
    uint64_t acc = 0;
    for (size_t i = 0; i < iters; i++) {
        compiler_memory_barrier();
        acc += fn(data, size) ^ (uint64_t)i;
    }
    return acc;
}

static double bench_hash(hash_fn fn, const unsigned char* data, size_t size) {
    size_t iters = 1024;
    for (;;) {
        double const t0 = now_sec();
        sink ^= run_loop(fn, data, size, iters);
        double const dt = now_sec() - t0;
        if (dt >= 0.08) break;
        if (iters > ((size_t)-1) / 2) break;
        iters *= 2;
    }

    double best = 0.0;
    for (int r = 0; r < 5; r++) {
        double const t0 = now_sec();
        sink ^= run_loop(fn, data, size, iters);
        double const dt = now_sec() - t0;
        double const gbps = ((double)size * (double)iters) / dt / 1000000000.0;
        if (gbps > best) best = gbps;
    }
    return best;
}

static const char* multiply_mode(void) {
#if defined(__wasm__)
    return "wasm";
#elif defined(__SIZEOF_INT128__)
    return "native_u128";
#else
    return "portable_32x32";
#endif
}

int main(void) {
    static const size_t sizes[] = {16, 64, 240, 1024, 102400, 1048576};
    size_t const max_size = 1048576;
    unsigned char* data = (unsigned char*)malloc(max_size);
    if (data == NULL) {
        fprintf(stderr, "failed to allocate %zu bytes\n", max_size);
        return 2;
    }

    for (size_t i = 0; i < max_size; i++) {
        data[i] = (unsigned char)(i * 131u + 17u);
    }

    printf("multiply_mode,%s\n\n", multiply_mode());
    puts("size,xxh64_GBps,xxh3_GBps,rapidhash_GBps");

    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        size_t const n = sizes[i];
        double const x64 = bench_hash(wrap_xxh64, data, n);
        double const x3  = bench_hash(wrap_xxh3,  data, n);
        double const r   = bench_hash(wrap_rapid, data, n);
        printf("%zu,%.3f,%.3f,%.3f\n", n, x64, x3, r);
    }

    free(data);
    return (int)(sink == 0x123456789abcdef0ULL);
}
