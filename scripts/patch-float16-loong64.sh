#!/bin/bash
# Patch float16 crate for LoongArch64 build
#
# float16 v0.1.5 includes LoongArch LSX SIMD optimizations using
# core::arch::loongarch64 intrinsics, which require the nightly-only
# stdarch_loongarch feature gate to be explicitly enabled.
#
# This script adds #![feature(stdarch_loongarch)] to the crate's lib.rs.

set -e

FLOAT16_SRC=$(find "$HOME/.cargo/registry/src" -maxdepth 3 -type d -name "float16-0.1.5" 2>/dev/null | head -1)

if [ -z "$FLOAT16_SRC" ]; then
    echo "Error: float16-0.1.5 source not found in cargo registry"
    echo "Run 'cargo fetch' or 'cargo build' first to download the crate."
    exit 1
fi

LIB_RS="$FLOAT16_SRC/src/lib.rs"

if grep -q 'feature(stdarch_loongarch)' "$LIB_RS" 2>/dev/null; then
    echo "Patch already applied to $LIB_RS"
    exit 0
fi

echo "Patching $LIB_RS ..."
sed -i '1s/^/#![feature(stdarch_loongarch)]\n/' "$LIB_RS"

echo "Patch applied successfully."
echo "Remember to run 'cargo clean -p float16' before rebuilding."
