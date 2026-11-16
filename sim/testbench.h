#pragma once
// 包裹 Verilator 生成的 Multiplier 的周期级驱动器 + 记分板。
#include "VMultiplier.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include "model.h"
#include "main.h"
#include "progress.h"

#include <deque>
#include <functional>
#include <memory>
#include <optional>
#include <random>
#include <string>
#include <vector>

namespace sim {
/// 握手节奏：控制 Testbench::run 每个周期的发送 / 接收行为。
/// 默认从不停顿；替换回调即可构造自己的停顿模式，例如：
///   Pacing p; p.ready = [&]{ return cycle++ % 3 == 0; };
struct Pacing {
    /// 本周期发送方是否可以送出新请求？（已送出的请求在被接收前保持不变）
    std::function<bool()> offer = [] { return true; };
    /// 本周期接收方是否 ready（愿意接收结果）？
    std::function<bool()> ready = [] { return true; };

    /// 从不停顿：每周期都发送、都 ready。
    static Pacing always() { return {}; }
    /// 随机停顿：发送方和接收方每周期各有 1/4 概率停顿。
    static Pacing random(std::mt19937_64& rng);
};

class Testbench {
    struct Expected {
        Request request;
        U128 product;
    };
    VerilatedContext context;
    VMultiplier dut{&context};
    std::unique_ptr<VerilatedFstC> trace;
    std::deque<Expected> expected;
    std::optional<U128> stalledOutput;
    uint64_t cycles_ = 0, accepted = 0, checked_ = 0, discarded = 0;
    uint64_t idleCycles = 0;
    const uint64_t timeout;
    ExhaustiveProgress* progress = nullptr;

    void eval();
    U128 product() const;

public:
    explicit Testbench(const Options& options);
    ~Testbench();
    Testbench(const Testbench&) = delete;
    Testbench& operator=(const Testbench&) = delete;

    // ---- 底层接口：逐周期控制 ----------------------------------------------------------

    /// 驱动一个时钟周期：送出 request（可为空，表示 valid=0），并设置 out.ready。
    /// 传输在上升沿之前采样（包括同周期响应）。被接收的请求会进入记分板，
    /// 每个输出结果都会与参考模型比对，不一致、超时或违反握手规则时抛出异常终止测试。
    /// @param request 本周期送入的请求；std::nullopt 表示不发送
    /// @param ready   本周期接收方是否 ready
    /// @return 请求是否被接收（valid 且设计的 in.ready 为 1）；未被接收时应在下个周期重发同一请求
    bool step(const std::optional<Request>& request, bool ready);

    /// 施加同步复位（持续 3 个周期），并丢弃所有在途请求。复位期间握手信号必须为 0。
    void reset();

    /// 不再发送新请求，等待所有在途请求返回并比对，之后再多观察 8 个周期以捕获多余 / 重复的输出。
    void drain();

    // ---- 高层接口 ----------------------------------------------------------------------

    /// 按顺序发送 requests 中的全部请求，节奏由 pacing 决定，最后自动 drain()。
    void run(const std::vector<Request>& requests, const Pacing& pacing);

    /// 同上；randomStalls 为 true 时使用 Pacing::random(rng)，否则从不停顿。
    void run(const std::vector<Request>& requests, std::mt19937_64& rng, bool randomStalls);

    /// 复位压力测试：先持续送入 request 并让输出保持 not-ready 以填满流水线 / 输出，
    /// 然后在请求仍挂在输入端时复位，确认在途请求都被取消。
    void resetDuringTraffic(const Request& request);

    /// 以当前周期号为前缀抛出异常，终止测试并报告 FAIL。
    [[noreturn]] void fail(const std::string& message) const;

    /// 最终核对记分板，并打印 PASS 摘要。所有测试结束后由 main 调用，学生无需调用。
    void report() const;

    /// 已经过的时钟周期数。
    uint64_t cycles() const { return cycles_; }
    /// 已核对通过的结果数。
    uint64_t checked() const { return checked_; }
    /// 挂接穷举进度显示（内置测试使用，学生无需调用）。
    void attachProgress(ExhaustiveProgress* p) { progress = p; }
};
} // namespace sim
