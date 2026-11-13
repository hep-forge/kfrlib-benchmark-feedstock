#! /usr/bin/bash
set -euo pipefail

# KFR's headers need this with GCC (its own build sets it, the installed
# CMake package does not pass it on); without it the NEON code of
# linux-aarch64 does not compile.
export CXXFLAGS="${CXXFLAGS:-} -flax-vector-conversions"

# ${CMAKE_ARGS} carries conda-build's -DCMAKE_BUILD_TYPE=Release and the
# toolchain paths. SINGLE (a list, with the recipe's patch) selects the
# libraries whose benchmark is built.
cmake -S . -B build -G Ninja ${CMAKE_ARGS} \
      -DCMAKE_PREFIX_PATH=$PREFIX \
      "-DSINGLE=kfr;fftw;kissfft"

cmake --build build -j${CPU_COUNT:-2}

# upstream has no install step: the programs are left in the build directory
mkdir -p $PREFIX/bin $PREFIX/share/kfrlib-benchmark
for program in build/fft_benchmark_* build/src_benchmark_*; do
    [ -f "$program" ] && [ -x "$program" ] && install -m 755 "$program" $PREFIX/bin/
done
cp plot.py spectrogram.py spectrum.py README.md $PREFIX/share/kfrlib-benchmark/
cp -r plans $PREFIX/share/kfrlib-benchmark/
