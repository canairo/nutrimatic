#!/usr/bin/env bash
# run_fuzz.sh — seed the corpus and start afl-fuzz
set -euo pipefail

mkdir -p corpus findings

# Seeds drawn from test-expr.cpp — diverse coverage of the grammar:
printf 'A' >corpus/s01_letter
printf 'Av*' >corpus/s02_star
printf 'Av+' >corpus/s03_plus
printf 'Av?' >corpus/s04_optional
printf 'Av{3}' >corpus/s05_exact
printf 'Av{2,5}' >corpus/s06_range
printf '(a|b)' >corpus/s07_union
printf '(a&b)' >corpus/s08_intersect
printf '[a-z]' >corpus/s09_charclass
printf '[^aeiou]' >corpus/s10_negclass
printf '<abc>' >corpus/s11_anagram
printf '"foo"' >corpus/s12_quoted
printf '#' >corpus/s13_digit
printf 'C' >corpus/s14_consonant
printf 'V' >corpus/s15_vowel
printf '.' >corpus/s16_dot
printf '_' >corpus/s17_underscore
printf '(a|b)*&[a-z]+' >corpus/s18_complex
printf '<het><ral><seg>' >corpus/s19_multi_anagram
printf '"<(cs)(dy)(er)>\"' >corpus/s20_quoted_anagram

# Tune ASAN options to avoid slowdowns from large allocations
export ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:malloc_context_size=0:symbolize=0"
export UBSAN_OPTIONS="abort_on_error=1:print_stacktrace=1"

# -D: deterministic stage first (good for structured input like this grammar)
# -x: use AFL's built-in dictionary for common regex tokens
afl-fuzz \
  -i corpus \
  -o findings \
  -D \
  -- ./fuzz_expr

# When done, triage with:
#   afl-collect -e fuzz_expr findings/ crashes/
#   for f in findings/default/crashes/id*; do ./fuzz_expr < "$f"; done
