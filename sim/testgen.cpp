#include "testgen.h"

#include "main.h"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace sim {
std::vector<Request> directedRequests() {
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

std::vector<Request> randomRequests(uint64_t count, std::mt19937_64& rng) {
    std::vector<Request> requests;
    for (uint64_t i = 0; i < count; ++i)
        requests.push_back({rng() & operandMask, rng() & operandMask,
                            testSigned && bool(rng() & 1), testSigned && bool(rng() & 1)});
    return requests;
}

std::vector<Request> filterEnabled(const std::vector<Request>& requests) {
    std::vector<Request> kept;
    std::copy_if(requests.begin(), requests.end(), std::back_inserter(kept), enabled);
    return kept;
}

std::vector<Request> loadRequests(const std::string& path) {
    std::ifstream file(path);
    if (!file) throw std::runtime_error("cannot open vectors: " + path);
    std::vector<Request> requests;
    std::string line;
    for (unsigned lineNo = 1; std::getline(file, line); ++lineNo) {
        line = line.substr(0, line.find('#'));
        std::istringstream fields(line);
        std::vector<std::string> tokens;
        for (std::string t; fields >> t;) tokens.push_back(t);
        if (tokens.empty()) continue;
        const std::string where = path + ":" + std::to_string(lineNo) + ": ";
        if (tokens.size() != 2 && tokens.size() != 4)
            throw std::runtime_error(where + "expected `a b [aSigned bSigned]`");
        requests.push_back({parseNumber(tokens[0]), parseNumber(tokens[1]),
                            tokens.size() == 4 && parseNumber(tokens[2]) != 0,
                            tokens.size() == 4 && parseNumber(tokens[3]) != 0});
    }
    return requests;
}
} // namespace sim
