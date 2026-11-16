#include "testbench.h"

#include <filesystem>
#include <iostream>
#include <stdexcept>

namespace sim {
Pacing Pacing::random(std::mt19937_64& rng) {
    Pacing p;
    p.offer = [&rng] { return rng() % 4 != 0; };
    p.ready = [&rng] { return rng() % 4 != 0; };
    return p;
}

Testbench::Testbench(const Options& options) : timeout(options.timeout) {
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

Testbench::~Testbench() {
    dut.final();
    if (trace) trace->close();
}

void Testbench::eval() {
    dut.eval();
    if (context.gotFinish()) fail("unexpected $finish");
    if (trace) trace->dump(context.time());
    context.timeInc(1);
}

U128 Testbench::product() const {
#if (2 * OPERAND_WIDTH) > 64
    U128 value = 0;
    for (unsigned i = 0; i < (2 * width + 31) / 32; ++i)
        value |= U128{dut.io_out_bits[i]} << (32 * i);
    return value;
#else
    return dut.io_out_bits;
#endif
}

void Testbench::fail(const std::string& message) const {
    if (progress && progress->active()) std::cout << '\n' << std::flush;
    throw std::runtime_error("cycle " + std::to_string(cycles_) + ": " + message);
}

bool Testbench::step(const std::optional<Request>& request, bool ready) {
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
        ++checked_;
        if (progress) progress->checked();
    }
    // Lack of progress is only counted when the consumer permits progress.
    if (outputFire || (!request && expected.empty())) idleCycles = 0;
    else if (ready && ++idleCycles > timeout) fail("no response/progress before timeout");
    dut.clock = 1;
    eval();
    ++cycles_;
    return inputFire;
}

void Testbench::reset() {
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
        ++cycles_;
    }
    dut.reset = 0;
}

void Testbench::drain() {
    while (!expected.empty()) step(std::nullopt, true);
    // Also catch spurious late or duplicate outputs after the queue is empty.
    for (unsigned i = 0; i < 8; ++i) step(std::nullopt, true);
}

void Testbench::run(const std::vector<Request>& requests, const Pacing& pacing) {
    size_t index = 0;
    std::optional<Request> held;
    while (index < requests.size()) {
        // A presented request stays valid and stable until accepted.
        if (!held && pacing.offer()) held = requests[index];
        const bool ready = pacing.ready();
        if (step(held, ready)) {
            held.reset();
            ++index;
        }
    }
    drain();
}

void Testbench::run(const std::vector<Request>& requests, std::mt19937_64& rng, bool randomStalls) {
    run(requests, randomStalls ? Pacing::random(rng) : Pacing::always());
}

void Testbench::resetDuringTraffic(const Request& request) {
    // Fill/stall the output, then reset even if a request is held at the input.
    // Reset explicitly cancels all accepted requests and any held source request.
    for (unsigned i = 0; i < 32; ++i) step(request, false);
    reset();
    drain();
}

void Testbench::report() const {
    if (!expected.empty() || accepted != checked_ + discarded)
        fail("scoreboard accounting mismatch");
    std::cout << "PASS width=" << width << " accepted=" << accepted << " checked=" << checked_
              << " reset_discarded=" << discarded << " cycles=" << cycles_ << '\n';
}
} // namespace sim
