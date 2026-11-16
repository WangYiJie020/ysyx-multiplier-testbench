// 在这里编写你自己的测试。运行方式：
//   make test SUITE=custom                                    （只运行本文件中的测试）
//   make test SUITE=all                                       （先运行内置测试，再运行本文件）
//   make test SUITE=custom VECTORS=student/tests/vectors.txt  （同时指定测试向量文件）
//
// 通过 tb 发出的所有请求都会自动与参考模型比对；
// 结果不一致时，测试会终止并打印出错的操作数和周期号。
// 注意：请求必须符合当前配置的测试范围（未启用 TEST_SIGNED 时不能使用有符号操作数）。
// 本文件之外的 sim/ 目录属于测试框架，不需要修改。
#include "student.h"

using namespace sim;

void customTests(Testbench& tb, std::mt19937_64& rng, const Options& options) {
    // 1. 手工构造的数据：Request{a, b, aSigned, bSigned}，符号标志默认为 0（无符号）。
    //    构造函数会自动用 operandMask 截断到当前位宽，无需手动处理。
    //    Pacing{} 表示不停顿：每周期都送入请求，输出端始终 ready。
    const std::vector<Request> mine = {
        Request{0, 0},
        Request{3, 5},
        Request{-1, -1}, // 截断后即 a = b = 全 1
    };
    tb.run(mine, Pacing{});

    // 2. 自定义方法（节奏）：每周期都送请求，但输出端每 3 个周期才 ready 一次。
    //    修改下面的 lambda，即可尝试任意停顿模式。
    unsigned cycle = 0;
    Pacing slowConsumer;
    slowConsumer.ready = [&cycle] { return ++cycle % 3 == 0; };
    tb.run(directedRequests(), slowConsumer);

    // 3. 从文件加载数据（见 student/tests/vectors.txt）。
    //    仅在命令行给出 VECTORS=文件 时执行；Pacing::random(rng) 为随机停顿。
    if (!options.vectors.empty()) tb.run(loadRequests(options.vectors), Pacing::random(rng));

    // 4. 逐周期控制：送入一个请求，随后让输出端保持一段时间 not ready。
    //    step() 返回 true 表示请求已被设计接收（否则下个周期需重发同一请求）。
    const Request one{operandMask, 2};
    while (!tb.step(one, false)) {}
    for (int i = 0; i < 5; ++i) tb.step(std::nullopt, false); // 不再送请求，仅让时钟前进
    tb.drain(); // 放行并核对结果
}
