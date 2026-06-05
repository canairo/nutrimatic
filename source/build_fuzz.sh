#!/usr/bin/env bash
# build_fuzz.sh — build fuzz_expr using the meson-built libs
#
# Strategy: let meson build the project normally (it knows the correct
# compiler flags and library versions for this environment), then compile
# just the fuzz harness against the resulting object files/libs.
#
# Usage (from nutrimatic/source/):
#   bash build_fuzz.sh

set -euo pipefail

SRC=$(dirname "$(realpath "$0")")
BUILDDIR="$SRC/builddir"

apt-get update
apt-get install -y --no-install-recommends \
  libfst-dev libtre-dev libxml2-dev meson ninja-build 2>&1 | grep -E '(install|already)'

find builddir -name "*.a" -o -name "*.o" | sort
find /usr /opt -name "libfst*" 2>/dev/null
cat builddir/build.ninja | grep -A5 "find-expr"

sed -i \
  's/isymbols_ = impl\.isymbols_ ? impl\.isymbols_->Copy() : nullptr;/isymbols_.reset(impl.isymbols_ ? impl.isymbols_->Copy() : nullptr);/' \
  /usr/include/fst/fst.h

sed -i \
  's/osymbols_ = impl\.osymbols_ ? impl\.osymbols_->Copy() : nullptr;/osymbols_.reset(impl.osymbols_ ? impl.osymbols_->Copy() : nullptr);/' \
  /usr/include/fst/fst.h

AFL_USE_ASAN=1 AFL_USE_UBSAN=1 \
  afl-c++ \
  -std=c++17 -O1 -g \
  -fno-omit-frame-pointer \
  -fsanitize=address,undefined \
  -fsanitize-recover=all \
  -Ibuilddir -I. \
  -Wno-ignored-qualifiers -Wno-sign-compare -Wno-overloaded-virtual \
  -Wno-unused-parameter -Wno-vla -Wno-dangling-pointer -Wno-missing-template-keyword \
  fuzz_expr.cpp \
  builddir/libexpr.so.p/expr-anagram.cpp.o \
  builddir/libexpr.so.p/expr-filter.cpp.o \
  builddir/libexpr.so.p/expr-intersect.cpp.o \
  builddir/libexpr.so.p/expr-optimize.cpp.o \
  builddir/libexpr.so.p/expr-parse.cpp.o \
  builddir/libindex.so.p/index-reader.cpp.o \
  builddir/libindex.so.p/index-walker.cpp.o \
  builddir/libindex.so.p/index-writer.cpp.o \
  builddir/libsearch.so.p/search-driver.cpp.o \
  builddir/libsearch.so.p/search-printer.cpp.o \
  -lfst -ltre \
  -o fuzz_expr
