#pragma once
// 请求类型与参考模型（golden model）。
#include "config.h"

#include <string>
#include <type_traits>

namespace sim {
/// 一次乘法请求。
/// 可直接用构造函数创建：Request{3, 5}、Request{x, y, true, false}。
struct Request {
    uint64_t a;     ///< 被乘数，仅低 width 位有效
    uint64_t b;     ///< 乘数，仅低 width 位有效
    bool aSigned;   ///< a 是否按有符号数解释（仅 TEST_SIGNED 时允许为 true）
    bool bSigned;   ///< b 是否按有符号数解释（仅 TEST_SIGNED 时允许为 true）

    constexpr Request() : a(0), b(0), aSigned(false), bSigned(false) {}

    /// 构造请求。a、b 可以是任意整数类型（包括负数字面量），会自动与 operandMask 相与，
    /// 超出位宽的高位被丢弃（因此 Request{-1, 1} 的 a 为全 1）；符号标志默认为 0（无符号）。
    template <typename A, typename B,
              std::enable_if_t<std::is_integral_v<A> && std::is_integral_v<B>, int> = 0>
    constexpr Request(A a, B b, bool aSigned = false, bool bSigned = false)
        : a(uint64_t(a) & operandMask), b(uint64_t(b) & operandMask),
          aSigned(aSigned), bSigned(bSigned) {}
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
