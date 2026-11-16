#include "builtin_tests.h"

#include "testgen.h"

namespace sim {
namespace {
void runExhaustive(Testbench& tb, std::mt19937_64& rng) {
    ExhaustiveProgress progress;
    tb.attachProgress(&progress);
    progress.begin();
    const unsigned signModes = testSigned ? 4 : 1;
    for (unsigned mode = 0; mode < signModes; ++mode) {
        // Sentinel comparisons avoid shifting by 64 or overflowing loop bounds.
        uint64_t a = 0;
        for (;;) {
            uint64_t b = 0;
            for (;;) {
                const Request request{a, b, bool(mode & 2), bool(mode & 1)};
                while (!tb.step(request, rng() % 4 != 0)) {}
                if (b == operandMask) break;
                ++b;
            }
            if (a == operandMask) break;
            ++a;
        }
    }
    tb.drain();
    progress.finish();
    tb.attachProgress(nullptr);
}
} // namespace

void runBuiltinTests(Testbench& tb, std::mt19937_64& rng, const Options& options) {
    const auto edges = directedRequests();
    if (testExhaustive) {
        ExhaustiveProgress::announce();
        runExhaustive(tb, rng);
    } else {
        tb.run(edges, rng, false);
        tb.run(edges, rng, true);
        tb.run(randomRequests(options.tests, rng), rng, true);
    }
    tb.resetDuringTraffic({operandMask, operandMask, testSigned, false});
    tb.run(edges, rng, true);
}
} // namespace sim
