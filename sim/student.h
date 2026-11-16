#pragma once
// 学生测试接口总入口：在 student/tests/custom_tests.cpp 中 #include "student.h" 即可。
//
//   数据   Request, directedRequests(), randomRequests(), loadRequests(), filterEnabled()
//   驱动   Testbench::run(requests, Pacing)  按自定义停顿节奏发送一组请求
//          Testbench::step(request, ready)   逐周期完全控制
//          Testbench::reset() / drain() / resetDuringTraffic()
//   常量   width, testSigned, operandMask
//
// 记分板会自动将每个结果与参考模型比对。
#include "builtin_tests.h"
#include "config.h"
#include "main.h"
#include "model.h"
#include "testbench.h"
#include "testgen.h"

/// 学生在 student/tests/custom_tests.cpp 中实现的入口函数，
/// 在 `make test SUITE=custom|all` 时被调用。
/// @param tb      测试平台，通过它发送请求、复位、推进时钟
/// @param rng     随机数引擎（种子由 SEED 决定，保证可复现）
/// @param options 命令行选项（如 options.vectors、options.tests）
void customTests(sim::Testbench& tb, std::mt19937_64& rng, const sim::Options& options);
