// AFL++ harness for nutrimatic expression parser (expr-parse.cpp)
//
// Build (after installing afl++ and openfst):
//
//   AFL_USE_ASAN=1 afl-c++ -std=c++17 -O1 -g \
//       -I/path/to/openfst/include \
//       fuzz_expr.cpp \
//       expr-parse.cpp expr-anagram.cpp expr-filter.cpp \
//       expr-intersect.cpp expr-optimize.cpp \
//       index-reader.cpp index-walker.cpp index-writer.cpp \
//       search-driver.cpp search-printer.cpp \
//       -lfst -ltre \
//       -fsanitize=address,undefined \
//       -fno-omit-frame-pointer \
//       -o fuzz_expr
//
// Then run:
//   mkdir -p corpus findings
//   echo -n 'A'      > corpus/seed1   # simple letter
//   echo -n 'Av*'    > corpus/seed2   # quantifier
//   echo -n '<abc>'  > corpus/seed3   # anagram
//   echo -n '[a-z]+' > corpus/seed4   # char class
//   echo -n '(a|b)'  > corpus/seed5   # alternation
//   afl-fuzz -i corpus -o findings -- ./fuzz_expr
//
// Notes:
//   - We fuzz ParseExpr() only (the top-level entry point); all sub-parsers
//     are reachable through it.
//   - We intentionally do NOT open an index file — that avoids file-system
//     noise and keeps coverage focused on parsing/FST construction, which is
//     where memory bugs are most likely to live.
//   - ASAN + UBSAN are both enabled. AFL_USE_ASAN=1 tells afl-c++ to link
//     the right runtime; the -fsanitize flags make clang/g++ instrument the
//     code.
//   - The harness is persistent-mode (LLVMFuzzerTestOneInput style via
//     __AFL_LOOP) for maximum throughput without forking overhead.

// Include order matters: search.h defines SearchFilter, which expr.h inherits from.
#include "index.h"
#include "search.h"
#include "expr.h"

#include "fst/vector-fst.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

using namespace fst;

// ── Persistent-mode AFL loop ─────────────────────────────────────────────────
// __AFL_LOOP(N) returns true up to N times per process, then exits cleanly.
// This gives ~10–100x throughput vs fork-server alone.
__AFL_FUZZ_INIT();

int main(int argc, char **argv) {
    __AFL_INIT();

    // AFL writes fuzzer input here; we get a pointer + length each iteration.
    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;

        // -----------------------------------------------------------------
        // 1. Build a null-terminated C string from the raw fuzz input.
        //    We cap at 4096 bytes — longer inputs rarely add coverage and
        //    slow things down considerably (FST construction can be O(n^2)).
        // -----------------------------------------------------------------
        if (len <= 0 || len > 4096) continue;

        char expr[4097];
        memcpy(expr, buf, len);
        expr[len] = '\0';

        // -----------------------------------------------------------------
        // 2. Call the top-level parser.
        //    ParseExpr walks the entire grammar:
        //      ParseExpr -> ParseBranch -> ParseFactor -> ParsePiece
        //                -> ParseAtom  -> ParseCharClass
        //                -> ParseAnagram
        //    A NULL return or a non-'\0' tail just means a parse error —
        //    that's expected and not a bug.
        // -----------------------------------------------------------------
        StdVectorFst fst;
        const char *tail = ParseExpr(expr, &fst, /*quoted=*/false);

        // -----------------------------------------------------------------
        // 3. If parsing succeeded, also exercise the optimizer and the
        //    ExprFilter constructor — both do non-trivial work on the FST
        //    and are worth covering.
        // -----------------------------------------------------------------
        if (tail != NULL && *tail == '\0') {
            // Optimize (determinize / minimize)
            StdVectorFst optimized;
            OptimizeExpr(fst, &optimized);

            // Build the DFA table used by the search driver
            ExprFilter filter(optimized);
            (void)filter.start();       // suppress unused-variable warning
        }
    }

    return 0;
}
