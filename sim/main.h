#pragma once
// 命令行选项（由 main.cpp 解析）。
#include <cstdint>
#include <string>

namespace sim {
/// 命令行选项，可在自定义测试中通过 customTests() 的 options 参数读取。
struct Options {
    uint64_t tests = 10000;   ///< --tests：随机测试的数量（对应 make 的 TESTS）
    uint64_t seed = 1;        ///< --seed：随机数种子（对应 SEED）
    uint64_t timeout = 10000; ///< --timeout：无进展的最大周期数（对应 TIMEOUT）
    std::string trace;        ///< --trace：波形文件路径，空表示不生成波形
    std::string suite = "builtin"; ///< --suite：builtin | custom | all（对应 SUITE）
    std::string vectors;      ///< --vectors：自定义测试向量文件，可为空（对应 VECTORS）

    bool runBuiltin() const { return suite != "custom"; }
    bool runCustom() const { return suite != "builtin"; }
};

/// 解析数字，支持十进制 / 0x 十六进制 / 0 开头八进制；空串、负号和多余字符会抛出异常。
uint64_t parseNumber(const std::string& text);

/// 解析命令行参数，非法参数抛出 std::runtime_error。
Options parseOptions(int argc, char** argv);
} // namespace sim
