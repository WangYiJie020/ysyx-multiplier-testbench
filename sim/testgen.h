#pragma once
// 测试数据的生成与加载，供自定义测试使用。
#include "model.h"

#include <random>
#include <string>
#include <vector>

namespace sim {
/// 生成边界值测试数据：0、1、2、全 1、符号位附近、0xAA.. / 0x55.. 图案、单个 1 位等，
/// 两两组合，并覆盖当前配置允许的所有符号组合。位宽 <= 4 时取遍所有操作数值。
std::vector<Request> directedRequests();

/// 生成 count 个均匀随机请求。仅在启用 TEST_SIGNED 时才会随机选择有符号。
std::vector<Request> randomRequests(uint64_t count, std::mt19937_64& rng);

/// 只保留符合当前测试范围的请求（见 enabled()）。
/// 例如把含有符号操作数的数据交给仅测无符号的配置前，可先过滤。
std::vector<Request> filterEnabled(const std::vector<Request>& requests);

/// 从文本文件加载测试向量。每行一条：`a b [aSigned bSigned]`，
/// 数字支持十进制或 0x 十六进制，`#` 之后为注释，符号标志缺省为 0。
/// 文件打不开、格式错误或操作数超出位宽时抛出异常（信息含文件名和行号）。
std::vector<Request> loadRequests(const std::string& path);
} // namespace sim
