#include "model.h"

#include <iomanip>
#include <sstream>

namespace sim {
std::string hex(U128 value) {
    std::ostringstream s;
    s << "0x" << std::hex << std::setfill('0');
    if (value >> 64) s << uint64_t(value >> 64) << std::setw(16);
    s << uint64_t(value);
    return s.str();
}

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
} // namespace sim
