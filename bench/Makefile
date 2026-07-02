BUILD_DIR ?= build
CC ?= cc

CFLAGS ?= -O3 -Wall -Wextra -std=c11
CPPFLAGS += -I ../../xxh3/upstream/xxHash -I ../../xxh3/upstream/rapidhash

.PHONY: all native run-native run-moon bench clean profile-wasm profile-wasm-tight

all: native

native: $(BUILD_DIR)/native_hash_bench

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/native_hash_bench: native_hash_bench.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(CPPFLAGS) $< -o $@

run-native: native
	$(BUILD_DIR)/native_hash_bench

run-moon-native:
	moon run --release --target native bench/moon_bench

run-moon-wasm:
	moon run --release --target wasm bench/moon_bench

run-moon-wasm-gc:
	moon run --release --target wasm-gc bench/moon_bench

run-moon: run-moon-native run-moon-wasm run-moon-wasm-gc

bench: run-native run-moon

# --- profiling (requires: cargo install moon-pprof --locked) ---

profile-wasm-tight: _build/wasm/debug/build/bench/wasm_profile/wasm_profile.wasm
	moon-pprof profile $< --out /tmp/xxh64-tight.pb.gz
	moon-pprof summary /tmp/xxh64-tight.pb.gz

profile-wasm-bench: _build/wasm/debug/build/bench/moon_bench/moon_bench.wasm
	moon-pprof profile $< --out /tmp/xxh64-bench.pb.gz
	moon-pprof summary /tmp/xxh64-bench.pb.gz

_build/wasm/debug/build/bench/wasm_profile/wasm_profile.wasm:
	moon build --debug --target wasm bench/wasm_profile

_build/wasm/debug/build/bench/moon_bench/moon_bench.wasm:
	moon build --debug --target wasm bench/moon_bench

clean:
	rm -rf $(BUILD_DIR)
