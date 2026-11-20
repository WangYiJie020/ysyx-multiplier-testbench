#pragma once
// 请求类型与参考模型（golden model）。
#include "config.h"

#include <string>
#include <type_traits>

namespace sim {
namespace detail {
// Nonnegative inputs can supply any raw bit pattern. For a negative input, only
// redundant sign-extension bits may be discarded. Compare unsigned values to
// avoid negating INT64_MIN or shifting by 64 at the widest configuration.
template <typename T>
constexpr bool truncatesOperand(T value) {
    const auto bits = uint64_t(value);
    if constexpr (std::is_signed_v<T>) {
        if (value < 0) return ~bits > (operandMask >> 1);
    }
    return bits > operandMask;
}

void warnRuntimeTruncation(char operand, uint64_t bits, bool negative);

// Kept out of line so GCC/Clang can diagnose a surviving call. The call itself
// is a no-op: a diagnostic already appeared during compilation.
[[gnu::warning("Request operand will be truncated to OPERAND_WIDTH bits")]]
void warnConstantTruncation();

template <typename T>
[[gnu::always_inline]] inline constexpr uint64_t checkedOperand(char operand, T value) {
    // In C++17 the compiler builtin preserves constexpr use of the constructor.
    if (!__builtin_is_constant_evaluated() && truncatesOperand(value)) {
        if (__builtin_constant_p(value)) warnConstantTruncation();
        else warnRuntimeTruncation(operand, uint64_t(value), std::is_signed_v<T> && value < T{0});
    }
    return uint64_t(value) & operandMask;
}

template <bool Truncates>
struct ConstantOperandCheck {
    static constexpr void check() {}
};
template <>
struct ConstantOperandCheck<true> {
    [[deprecated("Request operand will be truncated to OPERAND_WIDTH bits")]]
    static constexpr void check() {}
};
} // namespace detail

/// 一次乘法请求。
/// 可直接用构造函数创建：Request{3, 5}、Request{x, y, true, false}。
struct Request {
    uint64_t a;     ///< 被乘数，仅低 width 位有效
    uint64_t b;     ///< 乘数，仅低 width 位有效
    bool aSigned;   ///< a 是否按有符号数解释（仅 TEST_SIGNED 时允许为 true）
    bool bSigned;   ///< b 是否按有符号数解释（仅 TEST_SIGNED 时允许为 true）

    constexpr Request() : a(0), b(0), aSigned(false), bSigned(false) {}

    /// 构造请求。a、b 会截取低 width 位；丢失有效位时报警告。
    /// aSigned、bSigned 只控制如何解释截取后的位模式，不影响截断检查。
    template <typename A, typename B,
              std::enable_if_t<std::is_integral_v<A> && std::is_integral_v<B>, int> = 0>
    [[gnu::always_inline]] constexpr Request(A a, B b, bool aSigned = false, bool bSigned = false)
        : a(detail::checkedOperand('a', a)), b(detail::checkedOperand('b', b)),
          aSigned(aSigned), bSigned(bSigned) {}

    /// 显式检查常量操作数，不依赖优化级别，也适用于 constexpr 初始化。
    template <auto A, auto B,
              std::enable_if_t<std::is_integral_v<decltype(A)> && std::is_integral_v<decltype(B)>, int> = 0>
    static constexpr Request constant(bool aSigned = false, bool bSigned = false) {
        detail::ConstantOperandCheck<detail::truncatesOperand(A)>::check();
        detail::ConstantOperandCheck<detail::truncatesOperand(B)>::check();
        return Request{uint64_t(A) & operandMask, uint64_t(B) & operandMask, aSigned, bSigned};
    }
};

/// 将 value 格式化为 0x 开头的十六进制字符串（支持 128 位）。
std::string hex(U128 value);

/// 参考模型：返回完整的 2*width 位乘积。
/// 语义与 RISC-V M 扩展一致：MUL 取低半部分，MULH/MULHU/MULHSU 取高半部分，
/// 按 aSigned / bSigned 对操作数做符号扩展或零扩展。
U128 reference(const Request& r);

/// 请求是否符合当前配置的测试范围（未启用 TEST_SIGNED 时不允许有符号操作数）。
/// 不符合的请求发给 Testbench 会直接报错。
bool enabled(const Request& r);

/// 生成可读的请求描述，如 "a=0x3(u) b=0x5(u)"，用于报错信息。
std::string describe(const Request& r);
} // namespace sim
