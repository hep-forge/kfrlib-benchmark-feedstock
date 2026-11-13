#! /usr/bin/bash
set -euo pipefail

# KFR's headers convert between vector types implicitly. GCC needs
# -flax-vector-conversions for that (KFR's own build sets it, the installed
# CMake package does not pass it on; without it the NEON code of
# linux-aarch64 does not compile). For Clang the same spelling means
# "integer vectors only", so the Clang builds below ask for "all".
BASE_CXXFLAGS="${CXXFLAGS:-}"
export CXXFLAGS="${BASE_CXXFLAGS} -flax-vector-conversions"

# ${CMAKE_ARGS} carries conda-build's -DCMAKE_BUILD_TYPE=Release and the
# toolchain paths. SINGLE (a list, with the recipe's patch) selects the
# libraries whose benchmark is built.
cmake -S . -B build -G Ninja ${CMAKE_ARGS} \
      -DCMAKE_PREFIX_PATH=$PREFIX \
      "-DSINGLE=kfr;fftw;kissfft"

cmake --build build -j${CPU_COUNT:-2}

# The previous generations of KFR, from their sources (KFR_SRC_DIR). Their DFT
# needs Clang. On x86-64 the kernels are built for every instruction set and
# selected at runtime, as in the kfrlib package, with SSE2 as the baseline.
X86_ARGS=()
if [[ "$(uname -m)" == "x86_64" ]]; then
    X86_ARGS+=(-DKFR_ARCH=sse2 -DKFR_ENABLE_DFT_MULTIARCH=ON -DKFR_ENABLE_MULTIARCH=ON)
fi
for generation in 5 6; do
    CC=clang CXX=clang++ CXXFLAGS="${BASE_CXXFLAGS} -flax-vector-conversions=all" cmake -S . -B build-kfr${generation} -G Ninja ${CMAKE_ARGS} \
          -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
          -DSINGLE=kfr -DKFR_LEGACY=ON -DKFR_SRC_DIR=$SRC_DIR/kfr${generation} \
          -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DKFR_ENABLE_CAPI_BUILD=OFF \
          "${X86_ARGS[@]}"
    cmake --build build-kfr${generation} -j${CPU_COUNT:-2} --target fft_benchmark_kfr-any src_benchmark_kfr-any
done

# upstream has no install step: the programs are left in the build directory
mkdir -p $PREFIX/bin $PREFIX/share/kfrlib-benchmark
for program in build/fft_benchmark_* build/src_benchmark_*; do
    [ -f "$program" ] && [ -x "$program" ] && install -m 755 "$program" $PREFIX/bin/
done
for generation in 5 6; do
    install -m 755 build-kfr${generation}/fft_benchmark_kfr-any $PREFIX/bin/fft_benchmark_kfr${generation}-any
    install -m 755 build-kfr${generation}/src_benchmark_kfr-any $PREFIX/bin/src_benchmark_kfr${generation}-any
done
cp plot.py spectrogram.py spectrum.py README.md $PREFIX/share/kfrlib-benchmark/
cp -r plans $PREFIX/share/kfrlib-benchmark/
