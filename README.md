# YSYX 乘法器教学 Testbench

本项目提供了一套用于乘法器教学的 Verilog/Chisel 测试框架。它通过 `Kconfig` 管理配置，支持从简单组合逻辑到带握手接口的符号乘法器共五个教学阶段的自动化验证。

## 快速开始

### 依赖环境
确保已安装：Git, GNU Make >= 4.3, C/C++17 编译器, flex, bison, ncurses, Mill, JDK, Verilator 5.x。

### 构建与测试
```bash
# 1. 初始化工具
bash init.sh

# 2. 配置阶段与参数 (会打开菜单界面)
make menuconfig

# 3. 构建并执行自检
make

# 4. 运行测试 (SEED 为可选)
make test TESTS=100000 [SEED=42]
```

### Git Tracer
参考 ysyx 工作区的 tracer：`make rtl`、`make sim`、`make test`、`make wave` 会把当前工作区快照自动提交到 `tracer-ysyx` 分支（不影响当前分支、工作区与暂存区；遵守 `.gitignore`）。`test` / `wave` 运行结束后还会追加一次提交，在提交信息中记录 `PASS/FAIL`、退出码、耗时、配置与参数（`impl/stage/width/latency/...`、`TESTS/SEED/TIMEOUT`）以及仿真输出摘要；完整日志保存在 `build/<配置>/test.log`（不入库）。

**使用前请先在 `scripts/tracer.mk` 顶部填写自己的学号与姓名**（默认为占位符 `ysyx_00000000` / `Your Name`），或在命令行覆盖：`make test STUID=ysyx_12345678 STUNAME='Zhang San'`。

```bash
git log tracer-ysyx            # 查看追踪记录
make -f scripts/tracer.mk .clean_index  # 仅在提交异常中断、残留 .git/index.* 时使用
```

## 教学阶段
| 阶段 | 类型 | 握手 | 符号支持 | 对应的 Verilog 模块 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 组合逻辑 | 无 | 无 | `CombMultiplier.v` |
| 2 | 固定多周期 FSM | 无 | 无 | `MulticycleMultiplier.v` |
| 3 | 固定延迟流水线 | 无 | 无 | `PipelineMultiplier.v` |
| 4 | 带握手接口 | 有 | 无 | `HandshakeMultiplier.v` |
| 5 | 全功能接口 | 有 | 有 | `SignedMultiplier.v` |

*注：学员实现应修改 `student/rtl/` 中的对应文件（Verilog）或 `multiplier/src/multiplier/Students.scala`（Chisel）。*

## 配置与运行时参数

使用 `make menuconfig` 可修改硬件参数：
* **Student language**: 选择 Chisel 或 Verilog 实现。
* **Learning stage**: 切换教学阶段（1-5）。
* **Operand width**: 设置乘法器位宽 (1-64)。
* **Latency**: 设置阶段 2/3 的固定计算延迟。

运行时可通过 Make 变量覆盖默认行为，例如：
* `make test TESTS=1000`：调整测试样本量。
* `make wave`：生成 `wave.fst` 波形文件。
* `make regression`：执行多语言、五阶段全量回归测试。

## 测试框架说明
* **测试流程**：框架在学员模块外部包裹 Testbench，提供统一的请求/结果流，并记录状态机与记分板进行核对。
* **溢出处理**：以输出的 `2×WIDTH` 位完整乘积为准，测试始终覆盖输入范围，无溢出过滤。
* **全量测试**：在 `menuconfig` 中启用 `TEST_EXHAUSTIVE` 后，将遍历所有输入组合，适合位宽较小的穷举验证。

## 自定义测试（学生接口）
默认的 `builtin` 测试之外，可以在 `student/tests/custom_tests.cpp` 中实现 `customTests()`，用自己构造的数据或方法驱动设计；所有经 `tb` 发出的请求都会自动与参考模型比对。

```bash
make test SUITE=custom                                   # 只跑自定义测试
make test SUITE=all                                      # 内置 + 自定义
make test SUITE=custom VECTORS=student/tests/vectors.txt # 从文件加载测试向量
```

可用接口（均在 `namespace sim`，头文件 `sim/student.h`）：
* **数据**：`Request{a, b, aSigned = 0, bSigned = 0}`（构造时自动用 `operandMask` 截断到位宽）、`directedRequests()`、`randomRequests(n, rng)`、`loadRequests(file)`（每行 `a b [aSigned bSigned]`，支持 `#` 注释）、`filterEnabled(requests)`。
* **驱动**：`tb.run(requests, Pacing)` 按自定义的发送/接收停顿模式发送（`Pacing::always()`、`Pacing::random(rng)`，或自行设置 `offer` / `ready` 回调）；`tb.step(request, ready)` 逐周期控制；`tb.reset()`、`tb.drain()`、`tb.resetDuringTraffic(r)`。
* **常量**：`width`、`testSigned`、`operandMask`。

`sim/` 目录结构：`main.cpp` / `main.h`（入口与命令行选项）、`model.*`（请求与参考模型）、`testbench.*`（驱动与记分板）、`testgen.*`（数据生成/加载）、`builtin_tests.*`（内置测试）、`progress.*`（穷举进度）、`config.h`（编译期参数）。

---

## 附录：时序与接口约定

*   **阶段 2 (固定多周期)**：假设模块在复位后第 1, L+1, 2L+1... 个上升沿采样输入，在第 L, 2L, 3L... 个上升沿之后输出结果。学员需遵守该采样节拍。
*   **阶段 3 (流水线)**：每拍采样输入，经过 L 个上升沿后结果可用，允许每拍一组输入。
*   **阶段 4/5 (带握手)**：仅在 `valid && ready` 的上升沿传输；结果须按请求顺序返回；复位应取消在途请求。
*   **其他**：时序阶段均使用 `clock` 上升沿与同步高有效 `reset`。
