#include "VMultiplier.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <optional>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using U128 = unsigned __int128;
constexpr unsigned width = OPERAND_WIDTH;
constexpr bool testSigned = TEST_SIGNED;
constexpr bool testExhaustive = TEST_EXHAUSTIVE;
constexpr unsigned progressInterval = 1U << 20;
static_assert(width >= 1 && width <= 64);
constexpr uint64_t operandMask = std::numeric_limits<uint64_t>::max() >> (64 - width);
constexpr U128 resultMask = ~U128{0} >> (128 - 2 * width);

// Decimal strings keep totals exact even for 64-bit operands: up to 2^130 cases.
void addDecimal(std::string& value, unsigned increment) {
    for (size_t i = value.size(); i != 0 && increment != 0;) {
        const unsigned sum = unsigned(value[--i] - '0') + increment;
        value[i] = char('0' + sum % 10);
        increment = sum / 10;
    }
    if (increment) value.insert(0, std::to_string(increment));
}

std::string exhaustiveTotal() {
    std::string total = "1";
    for (unsigned bit = 0; bit < 2 * width + (testSigned ? 2 : 0); ++bit) {
        unsigned carry = 0;
        for (size_t i = total.size(); i != 0;) {
            const unsigned doubled = 2 * unsigned(total[--i] - '0') + carry;
            total[i] = char('0' + doubled % 10);
            carry = doubled / 10;
        }
        if (carry) total.insert(total.begin(), char('0' + carry));
    }
    return total;
}

void announceExhaustive() {
    const auto total = exhaustiveTotal();
    std::cout << "Exhaustive cases=" << total << std::endl;
    if (2 * width + (testSigned ? 2 : 0) > 24)
        std::cerr << "WARNING: exhaustive test has " << total
                  << " cases (> 2^24); this may take a long time." << std::endl;
}

struct Request {
    uint64_t a, b;
    bool aSigned, bSigned;
};

std::string hex(U128 value) {
    std::ostringstream s;
    s << "0x" << std::hex << std::setfill('0');
    if (value >> 64) s << uint64_t(value >> 64) << std::setw(16);
    s << uint64_t(value);
    return s.str();
}

// RISC-V M: MUL is the low word; MULH/MULHU/MULHSU are the high word
// of the signed/signed, unsigned/unsigned, signed/unsigned full product.
// Unsigned modular arithmetic explicitly models the ISA, without host signed overflow.
U128 reference(const Request& r) {
    auto extend = [](uint64_t bits, bool isSigned) -> U128 {
        U128 value = bits & operandMask;
        if (isSigned && ((bits >> (width - 1)) & 1)) value |= ~U128{operandMask};
        return value;
    };
    return (extend(r.a, r.aSigned) * extend(r.b, r.bSigned)) & resultMask;
}

bool enabled(const Request& r) {
    return testSigned || !(r.aSigned || r.bSigned);
}

std::string describe(const Request& r) {
    return "a=" + hex(r.a) + (r.aSigned ? "(s)" : "(u)") +
           " b=" + hex(r.b) + (r.bSigned ? "(s)" : "(u)");
}

struct Options {
    uint64_t tests = 10000, seed = 1, timeout = 10000;
    std::string trace;
};

uint64_t number(const std::string& text) {
    if (text.empty() || text.front() == '-') throw std::runtime_error("invalid number: " + text);
    size_t end = 0;
    const auto value = std::stoull(text, &end, 0);
    if (end != text.size()) throw std::runtime_error("invalid number: " + text);
    return value;
}

Options parse(int argc, char** argv) {
    Options o;
    for (int i = 1; i < argc; ++i) {
        const std::string key = argv[i];
        if (key == "--help") {
            std::cout << "--tests N --seed N --timeout CYCLES --trace FILE.fst\n";
            std::exit(0);
        }
        if (i + 1 == argc) throw std::runtime_error("missing value for " + key);
        const std::string value = argv[++i];
        if (key == "--tests") o.tests = number(value);
        else if (key == "--seed") o.seed = number(value);
        else if (key == "--timeout") o.timeout = number(value);
        else if (key == "--trace") o.trace = value;
        else throw std::runtime_error("unknown option: " + key);
    }
    if (o.timeout == 0) throw std::runtime_error("timeout must be positive");
    return o;
}

class Testbench {
    struct Expected {
        Request request;
        U128 product;
    };
    VerilatedContext context;
    VMultiplier dut{&context};
    std::unique_ptr<VerilatedFstC> trace;
    std::deque<Expected> expected;
    std::optional<U128> stalledOutput;
    uint64_t cycles = 0, accepted = 0, checked = 0, discarded = 0;
    uint64_t idleCycles = 0;
    const uint64_t timeout;
    bool exhaustiveActive = false;
    unsigned exhaustiveBatch = 0;
    std::string exhaustiveCompleted = "0";

    void printExhaustiveProgress(bool complete = false) const {
        const auto total = exhaustiveTotal();
        const long double percent = std::stold(exhaustiveCompleted) / std::stold(total) * 100;
        std::ostringstream formatted;
        formatted << std::fixed << std::setprecision(2) << percent;
        std::cout << '\r' << "Exhaustive progress: " << exhaustiveCompleted
                  << "/" << total << " (" << formatted.str() << "%)";
        if (complete) std::cout << '\n';
        std::cout << std::flush;
    }

    void checkedExhaustive() {
        if (exhaustiveActive && ++exhaustiveBatch == progressInterval) {
            addDecimal(exhaustiveCompleted, exhaustiveBatch);
            exhaustiveBatch = 0;
            printExhaustiveProgress();
        }
    }

    void eval() {
        dut.eval();
        if (context.gotFinish()) fail("unexpected $finish");
        if (trace) trace->dump(context.time());
        context.timeInc(1);
    }

    U128 product() const {
#if (2 * OPERAND_WIDTH) > 64
        U128 value = 0;
        for (unsigned i = 0; i < (2 * width + 31) / 32; ++i)
            value |= U128{dut.io_out_bits[i]} << (32 * i);
        return value;
#else
        return dut.io_out_bits;
#endif
    }

public:
    explicit Testbench(const Options& options) : timeout(options.timeout) {
        if (!options.trace.empty()) {
            const auto parent = std::filesystem::path(options.trace).parent_path();
            if (!parent.empty()) std::filesystem::create_directories(parent);
            context.traceEverOn(true);
            trace = std::make_unique<VerilatedFstC>();
            dut.trace(trace.get(), 99);
            trace->open(options.trace.c_str());
            if (!trace->isOpen()) throw std::runtime_error("cannot open trace: " + options.trace);
        }
        dut.clock = 0;
        dut.reset = 0;
        dut.io_in_valid = 0;
        dut.io_out_ready = 0;
        dut.io_in_bits_a = 0;
        dut.io_in_bits_b = 0;
        dut.io_in_bits_aSigned = 0;
        dut.io_in_bits_bSigned = 0;
    }

    ~Testbench() {
        dut.final();
        if (trace) trace->close();
    }

    [[noreturn]] void fail(const std::string& message) const {
        if (exhaustiveActive) std::cout << '\n' << std::flush;
        throw std::runtime_error("cycle " + std::to_string(cycles) + ": " + message);
    }

    // Transfers are sampled BEFORE the rising edge, including same-cycle responses.
    bool step(const std::optional<Request>& request, bool ready) {
        if (request && !enabled(*request)) fail("request violates configured test coverage");
        dut.clock = 0;
        dut.io_in_valid = request.has_value();
        if (request) {
            dut.io_in_bits_a = request->a;
            dut.io_in_bits_b = request->b;
            dut.io_in_bits_aSigned = request->aSigned;
            dut.io_in_bits_bSigned = request->bSigned;
        }
        dut.io_out_ready = ready;
        eval();
        if (stalledOutput && (!dut.io_out_valid || product() != *stalledOutput))
            fail("output changed while valid=1 and ready=0");
        const bool inputFire = request && dut.io_in_ready;
        const bool outputFire = dut.io_out_valid && ready;
        if (inputFire) {
            expected.push_back({*request, reference(*request)});
            ++accepted;
        }
        if (outputFire) {
            if (expected.empty()) fail("unexpected or duplicate response");
            const auto& front = expected.front();
            if (product() != front.product)
                fail(describe(front.request) + " expected=" + hex(front.product) +
                     " actual=" + hex(product()));
        }
        stalledOutput = dut.io_out_valid && !ready ? std::optional<U128>{product()} : std::nullopt;
        if (outputFire) {
            expected.pop_front();
            ++checked;
            checkedExhaustive();
        }
        // Lack of progress is only counted when the consumer permits progress.
        if (outputFire || (!request && expected.empty())) idleCycles = 0;
        else if (ready && ++idleCycles > timeout) fail("no response/progress before timeout");
        dut.clock = 1;
        eval();
        ++cycles;
        return inputFire;
    }

    void reset() {
        discarded += expected.size();
        expected.clear();
        stalledOutput.reset();
        idleCycles = 0;
        dut.reset = 1;
        dut.io_in_valid = 0;
        dut.io_out_ready = 0;
        for (int i = 0; i < 3; ++i) {
            dut.clock = 0;
            eval();
            if (dut.io_in_ready || dut.io_out_valid) fail("handshake enabled during reset");
            dut.clock = 1;
            eval();
            ++cycles;
        }
        dut.reset = 0;
    }

    void drain() {
        while (!expected.empty()) step(std::nullopt, true);
        // Also catch spurious late or duplicate outputs after the queue is empty.
        for (unsigned i = 0; i < 8; ++i) step(std::nullopt, true);
    }

    void run(const std::vector<Request>& requests, std::mt19937_64& rng, bool randomStalls) {
        size_t index = 0;
        std::optional<Request> held;
        while (index < requests.size()) {
            // A presented request stays valid and stable until accepted.
            if (!held && (!randomStalls || rng() % 4 != 0)) held = requests[index];
            const bool ready = !randomStalls || rng() % 4 != 0;
            if (step(held, ready)) {
                held.reset();
                ++index;
            }
        }
        drain();
    }

    void runExhaustive(std::mt19937_64& rng) {
        exhaustiveActive = true;
        printExhaustiveProgress();
        const unsigned signModes = testSigned ? 4 : 1;
        for (unsigned mode = 0; mode < signModes; ++mode) {
            // Sentinel comparisons avoid shifting by 64 or overflowing loop bounds.
            uint64_t a = 0;
            for (;;) {
                uint64_t b = 0;
                for (;;) {
                    const Request request{a, b, bool(mode & 2), bool(mode & 1)};
                    while (!step(request, rng() % 4 != 0)) {}
                    if (b == operandMask) break;
                    ++b;
                }
                if (a == operandMask) break;
                ++a;
            }
        }
        drain();
        exhaustiveActive = false;
        addDecimal(exhaustiveCompleted, exhaustiveBatch);
        printExhaustiveProgress(true);
    }

    void resetDuringTraffic(const Request& request) {
        // Fill/stall the output, then reset even if a request is held at the input.
        // Reset explicitly cancels all accepted requests and any held source request.
        for (unsigned i = 0; i < 32; ++i) step(request, false);
        reset();
        drain();
    }

    void report() const {
        if (!expected.empty() || accepted != checked + discarded)
            fail("scoreboard accounting mismatch");
        std::cout << "PASS width=" << width << " accepted=" << accepted << " checked=" << checked
                  << " reset_discarded=" << discarded << " cycles=" << cycles << '\n';
    }
};

std::vector<Request> directed() {
    const uint64_t sign = uint64_t{1} << (width - 1);
    std::vector<uint64_t> values{0, 1, 2 & operandMask, operandMask,
                                operandMask - 1, sign, sign - 1, (sign + 1) & operandMask,
                                0xaaaaaaaaaaaaaaaaULL & operandMask,
                                0x5555555555555555ULL & operandMask};
    for (unsigned bit = 0; bit < width; ++bit) values.push_back(uint64_t{1} << bit);
    std::sort(values.begin(), values.end());
    values.erase(std::unique(values.begin(), values.end()), values.end());
    if (width <= 4) {
        values.clear();
        for (uint64_t v = 0; v <= operandMask; ++v) values.push_back(v);
    }
    std::vector<Request> requests;
    for (bool as : {false, true})
        for (bool bs : {false, true})
            for (uint64_t a : values)
                for (uint64_t b : values) {
                    const Request r{a, b, as, bs};
                    if (enabled(r)) requests.push_back(r);
                }
    return requests;
}
} // namespace

int main(int argc, char** argv) {
    try {
        const Options options = parse(argc, argv);
        std::cout << "seed=" << options.seed << " random_tests=" << options.tests
                  << " signed=" << testSigned << " exhaustive=" << testExhaustive << '\n';
        std::mt19937_64 rng(options.seed);
        if (testExhaustive) announceExhaustive();
        Testbench tb(options);
        tb.reset();
        const auto edges = directed();
        if (testExhaustive) {
            tb.runExhaustive(rng);
        } else {
            tb.run(edges, rng, false);
            tb.run(edges, rng, true);
            std::vector<Request> random;
            for (uint64_t i = 0; i < options.tests; ++i)
                random.push_back({rng() & operandMask, rng() & operandMask,
                                  testSigned && bool(rng() & 1), testSigned && bool(rng() & 1)});
            tb.run(random, rng, true);
        }
        tb.resetDuringTraffic({operandMask, operandMask, testSigned, false});
        tb.run(edges, rng, true);
        tb.report();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
