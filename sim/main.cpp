#include "main.h"

#include "student.h"

#include <cstdlib>
#include <iostream>
#include <stdexcept>

namespace sim {
uint64_t parseNumber(const std::string& text) {
    if (text.empty() || text.front() == '-') throw std::runtime_error("invalid number: " + text);
    size_t end = 0;
    const auto value = std::stoull(text, &end, 0);
    if (end != text.size()) throw std::runtime_error("invalid number: " + text);
    return value;
}

Options parseOptions(int argc, char** argv) {
    Options o;
    for (int i = 1; i < argc; ++i) {
        const std::string key = argv[i];
        if (key == "--help") {
            std::cout << "--tests N --seed N --timeout CYCLES --trace FILE.fst\n"
                         "--suite builtin|custom|all --vectors FILE\n";
            std::exit(0);
        }
        if (i + 1 == argc) throw std::runtime_error("missing value for " + key);
        const std::string value = argv[++i];
        if (key == "--tests") o.tests = parseNumber(value);
        else if (key == "--seed") o.seed = parseNumber(value);
        else if (key == "--timeout") o.timeout = parseNumber(value);
        else if (key == "--trace") o.trace = value;
        else if (key == "--suite") o.suite = value;
        else if (key == "--vectors") o.vectors = value;
        else throw std::runtime_error("unknown option: " + key);
    }
    if (o.timeout == 0) throw std::runtime_error("timeout must be positive");
    if (o.suite != "builtin" && o.suite != "custom" && o.suite != "all")
        throw std::runtime_error("suite must be builtin, custom or all");
    return o;
}
} // namespace sim

int main(int argc, char** argv) {
    using namespace sim;
    try {
        const Options options = parseOptions(argc, argv);
        std::cout << "seed=" << options.seed << " random_tests=" << options.tests
                  << " signed=" << testSigned << " exhaustive=" << testExhaustive
                  << " suite=" << options.suite << '\n';
        std::mt19937_64 rng(options.seed);
        Testbench tb(options);
        tb.reset();
        if (options.runBuiltin()) runBuiltinTests(tb, rng, options);
        if (options.runCustom()) customTests(tb, rng, options);
        tb.report();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
