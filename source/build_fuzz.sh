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
  libfst-dev libtre-dev libxml2-dev meson ninja-build neovim unzip valgrind uuid-dev default-jre python3 2>&1 | grep -E '(install|already)'

wget https://www.antlr.org/download/antlr-4.8-complete.jar
cp -f antlr-4.8-complete.jar /usr/local/lib

meson setup builddir
meson compile -C builddir

find builddir -name "*.a" -o -name "*.o" | sort
find /usr /opt -name "libfst*" 2>/dev/null
cat builddir/build.ninja | grep -A5 "find-expr"

sed -i \
  's/isymbols_ = impl\.isymbols_ ? impl\.isymbols_->Copy() : nullptr;/isymbols_.reset(impl.isymbols_ ? impl.isymbols_->Copy() : nullptr);/' \
  /usr/include/fst/fst.h

sed -i \
  's/osymbols_ = impl\.osymbols_ ? impl\.osymbols_->Copy() : nullptr;/osymbols_.reset(impl.osymbols_ ? impl.osymbols_->Copy() : nullptr);/' \
  /usr/include/fst/fst.h

cd /AFLplusplus/custom_mutators/grammar_mutator
sed -i 's/grammar_mutator/grammar-mutator/g' /AFLplusplus/custom_mutators/grammar_mutator/build_grammar_mutator.sh

./build_grammar_mutator.sh
cd grammar-mutator
make GRAMMAR_FILE=/src/source/nutrimatic.json

/AFLplusplus/custom_mutators/grammar_mutator/grammar-mutator/grammar_generator-nutrimatic 100 8 /src/source/corpus_grammar /src/source/corpus_grammar_trees

cd /src/source
mkdir -p findings_grammar
