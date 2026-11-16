#include "progress.h"

#include "config.h"

#include <iomanip>
#include <iostream>
#include <sstream>

namespace sim {
namespace {
constexpr unsigned progressInterval = 1U << 20;

void addDecimal(std::string& value, unsigned increment) {
    for (size_t i = value.size(); i != 0 && increment != 0;) {
        const unsigned sum = unsigned(value[--i] - '0') + increment;
        value[i] = char('0' + sum % 10);
        increment = sum / 10;
    }
    if (increment) value.insert(0, std::to_string(increment));
}
} // namespace

// Decimal strings keep totals exact even for 64-bit operands: up to 2^130 cases.
std::string ExhaustiveProgress::total() {
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

void ExhaustiveProgress::announce() {
    const auto count = total();
    std::cout << "Exhaustive cases=" << count << std::endl;
    if (2 * width + (testSigned ? 2 : 0) > 24)
        std::cerr << "WARNING: exhaustive test has " << count
                  << " cases (> 2^24); this may take a long time." << std::endl;
}

void ExhaustiveProgress::begin() {
    active_ = true;
    print();
}

void ExhaustiveProgress::checked() {
    if (active_ && ++batch_ == progressInterval) {
        addDecimal(completed_, batch_);
        batch_ = 0;
        print();
    }
}

void ExhaustiveProgress::finish() {
    active_ = false;
    addDecimal(completed_, batch_);
    batch_ = 0;
    print(true);
}

void ExhaustiveProgress::print(bool complete) const {
    const long double percent = std::stold(completed_) / std::stold(total_) * 100;
    std::ostringstream formatted;
    formatted << std::fixed << std::setprecision(2) << percent;
    std::cout << '\r' << "Exhaustive progress: " << completed_
              << "/" << total_ << " (" << formatted.str() << "%)";
    if (complete) std::cout << '\n';
    std::cout << std::flush;
}
} // namespace sim
