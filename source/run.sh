#!/bin/bash

export TERM=xterm-256color

AFL_CUSTOM_MUTATOR_LIBRARY=/AFLplusplus/custom_mutators/grammar_mutator/grammar-mutator/libgrammarmutator-nutrimatic.so \
  AFL_CUSTOM_MUTATOR_ONLY=1 \
  GRAMMAR_MUTATOR_RULES_FILE=/src/source/nutrimatic.json \
  ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:symbolize=0" \
  UBSAN_OPTIONS="abort_on_error=1:print_stacktrace=0" \
  afl-fuzz \
  -i /src/source/corpus_grammar \
  -o findings_grammar \
  -D \
  -- ./fuzz_expr
