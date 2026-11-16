#pragma once
// Progress reporting for exhaustive runs (totals can reach 2^130, so counts are decimal strings).
#include <string>

namespace sim {
class ExhaustiveProgress {
public:
    // Total number of cases for the configured width / signedness, as a decimal string.
    static std::string total();
    // Print the case count and warn when the run is very large.
    static void announce();

    void begin();
    void checked(); // call once per verified result
    void finish();
    bool active() const { return active_; }

private:
    void print(bool complete = false) const;

    std::string total_ = total();
    std::string completed_ = "0";
    unsigned batch_ = 0;
    bool active_ = false;
};
} // namespace sim
