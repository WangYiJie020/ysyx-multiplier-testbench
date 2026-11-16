#pragma once
// 默认（内置）测试集。
#include "main.h"
#include "testbench.h"

#include <random>

namespace sim {
void runBuiltinTests(Testbench& tb, std::mt19937_64& rng, const Options& options);
} // namespace sim
