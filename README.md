# YSYX 乘法器教学 Testbench

本项目提供了一套用于乘法器教学的 Verilog/Chisel 测试框架。它通过 `Kconfig` 管理配置，按讲义预置了多种乘法器实现（ROM、累加、移位加、流水线、Wallace 树、Booth2+Wallace 等），每种实现描述自己的接口/时序特征，由框架自动适配并验证。

## 快速开始

### 依赖环境
确保已安装：Git, GNU Make >= 4.3, C/C++17 编译器, flex, bison, ncurses, Verilator 5.x。

**使用 Chisel 的学员**另需安装 Mill 与 JDK（环境独立放在 `chisel/` 目录）；使用 Verilog 的学员无需任何 Chisel/Scala 环境。

### 构建与测试
```bash
# 1. 初始化工具
bash init.sh

# 2. 选择语言、实现与参数 (会打开菜单界面；缺省为 Verilog + A*B 直接乘法)
make menuconfig
#    也可直接加载预设：make defconfig DEFCONFIG=configs/chisel_defconfig

# 3. 构建并执行自检（等价于 make test）
make

# 4. 运行测试 (SEED 为可选)
make test TESTS=100000 [SEED=42]
```

**测试讲义中的每个阶段前，先运行 `make menuconfig`，在 `Multiplier implementation` 中选择该任务对应的实现（见下表），保存后再运行 `make test`。** 例如，测试任务二时选累加乘法器（`accum`）。`make test` 只测试当前选中的实现，不会自动切换阶段。

`make test` 和 `make wave` 在开始仿真时会显示当前实现的名称、ID、语言和位宽，例如：

```text
===== 当前测试实现：累加乘法器 (accum) | verilog | 位宽 8 =====
```

### Git Tracer
参考 ysyx 工作区的 tracer：`make rtl`、`make sim`、`make test`、`make wave` 会把当前工作区快照自动提交到 `tracer-ysyx` 分支（不影响当前分支、工作区与暂存区；遵守 `.gitignore`）。`test` / `wave` 运行结束后还会追加一次提交，在提交信息中记录 `PASS/FAIL`、退出码、耗时、配置与参数（`hdl/impl/width/latency/...`、`TESTS/SEED/TIMEOUT`）以及仿真输出摘要；完整日志保存在 `build/<配置>/test.log`（不入库）。

**使用前请先在 `scripts/tracer.mk` 顶部填写自己的学号与姓名**（默认为占位符 `ysyx_00000000` / `Your Name`），或在命令行覆盖：`make test STUID=ysyx_12345678 STUNAME='Zhang San'`。

```bash
git log tracer-ysyx            # 查看追踪记录
make -f scripts/tracer.mk .clean_index  # 仅在提交异常中断、残留 .git/index.* 时使用
```

## 乘法器实现
每种实现有独立的 Verilog 文件（`student/rtl/<模块>.v`）和 Chisel 文件（`chisel/multiplier/src/multiplier/impls/<模块>.scala`），只需修改自己所用语言的那一个，缺省内容均为直接使用 `A*B` 的范例实现（已满足该实现的接口约定），在 `缺省实现开始/结束` 之间改写即可。

| id | 实现（讲义） | 时钟 | 延迟 | 流水化输入 | 握手 | 模块 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `direct` | A*B 直接乘法 | 无（组合） | — | — | 无 | `DirectMultiplier` |
| `rom` | ROM 查表（位宽 ≤ 8） | 无（组合） | — | — | 无 | `RomMultiplier` |
| `comb_add` | 组合逻辑部分积累加（任务一） | 无（组合） | — | — | 无 | `CombAddMultiplier` |
| `accum` | 累加乘法器（任务二） | 有 | 固定 = WIDTH | 否 | 无 | `AccumMultiplier` |
| `shift_add` | 移位加乘法器（任务三） | 有 | 可变（可提前结束） | — | 有 | `ShiftAddMultiplier` |
| `pipe_accum` | 流水线化累加（任务四） | 有 | 固定 = WIDTH | 是 | 无 | `PipelinedAccumMultiplier` |
| `pipe_shift_add` | 流水线化移位加（任务四） | 有 | 固定 = WIDTH | 是 | 无 | `PipelinedShiftAddMultiplier` |
| `wallace` | Wallace 树（任务五） | 有 | 固定，缺省 CSA 层数+1，可配置 | 是 | 无 | `WallaceMultiplier` |
| `booth_wallace` | Booth2 + Wallace 树（任务六） | 有 | 固定，缺省 CSA 层数+1，可配置 | 是 | 无 | `BoothWallaceMultiplier` |
| `signed_direct` | 有符号 A*B（`a_signed`/`b_signed`） | 有 | 可变 | — | 有 | `SignedDirectMultiplier` |

*注：树形乘法器讲义明确无需实现，未预置。Verilog 的辅助模块请放在 `student/rtl/common/`（始终参与编译）；其他实现的骨架文件不会参与编译。Chisel 辅助模块直接写在 Chisel 源文件中，生成时每个模块一个文件。*

### 描述一种新实现
接口/时序特征写在 `impls/<id>.mk`（Makefile 变量，测试适配器与构建流程据此推导，无需 Chisel）：

| 变量 | 含义 |
| :--- | :--- |
| `IMPL_MODULE` | 实例化的模块名（Verilog 文件 `student/rtl/<模块>.v`，Chisel 类同名） |
| `IMPL_CLOCKED` | 是否有 `clock`/`reset`（0 = 纯组合逻辑） |
| `IMPL_FIXED_CYCLE` | 固定延迟：采样输入后恰好 `LATENCY` 个上升沿出结果（Verilog 模块多一个 `LATENCY` 参数） |
| `IMPL_PIPELINED` | 固定延迟时是否每拍可送入一组输入；否则每 `LATENCY` 拍采样一次 |
| `IMPL_HANDSHAKE` | `in_valid/in_ready/out_valid/out_ready` 握手，延迟可变，结果按序 |
| `IMPL_SIGNED` | 额外有 `a_signed/b_signed`（需握手） |
| `IMPL_DEFAULT_LATENCY` / `IMPL_LATENCY_CONFIGURABLE` | 由 `$(WIDTH)` 推导的缺省延迟；是否允许 menuconfig 覆盖 |
| `IMPL_MAX_WIDTH` | 位宽上限 |

新增实现的步骤：添加 `impls/<id>.mk`；在 `student/rtl/` 放同名 `.v`；在 `Kconfig` 的 `Multiplier implementation` 中添加选项与 `MUL` 的 id；如需 Chisel 版本，再在 `chisel/` 中添加模块并登记到 `Impls.scala`。

### Verilog 与 Chisel 的分工
* 测试平台适配器是纯 SystemVerilog（`sim/rtl/Multiplier.sv`），由构建时生成的 `mul_config.svh` 参数化；Verilog 学员的模块被直接实例化（参数 `WIDTH`，固定延迟时再加 `LATENCY`）。
* Chisel 学员选择 `Chisel` 后，`make` 会在 `chisel/` 子工程中用 Mill 把学员模块生成为同名 Verilog（`build/<配置>/chisel/`），再走同一套仿真流程；Chisel 模块使用 `FlatIO`，端口与 Verilog 版完全一致（`a`、`b`、`product`、`in_valid`…）。

## 配置与运行时参数

使用 `make menuconfig` 可修改硬件参数：
* **Student language**: 选择 Verilog（缺省）或 Chisel 实现（仅 Chisel 需要 Mill/JDK）。
* **Multiplier implementation**: 选择上表中的实现。
* **Operand width**: 设置乘法器位宽 (1-64，`rom` 限 1-8)。
* **Latency override**: 仅对延迟可配置的实现（Wallace 系列）有效，0 表示使用实现缺省值。

运行时可通过 Make 变量覆盖默认行为，例如：
* `make test TESTS=1000`：调整测试样本量。
* `make wave`：生成 `wave.fst` 波形文件。
* `make rtl`：仅生成/准备 RTL（Chisel 时生成 Verilog，Verilog 时只生成适配器参数）。
* `make compile`（等价于 `make sim`）：按当前语言配置构建仿真器，不运行测试。
* `make regression`：对两种语言、全部实现执行全量回归测试（会改写并在结束后恢复 `.config`；包含 Chisel，因此需要 Mill/JDK）。

配置或清理后再单独执行构建，例如 `make defconfig && make compile`，不要把会修改配置或构建产物的目标与编译目标放在同一次 `make` 调用中。

## 测试框架说明
* **测试流程**：框架在学员模块外部包裹适配器与 Testbench，提供统一的请求/结果流，并记录状态机与记分板进行核对。
* **溢出处理**：以输出的 `2×WIDTH` 位完整乘积为准，测试始终覆盖输入范围，无溢出过滤。
* **有符号测试**：仅 `signed_direct` 支持，在 `menuconfig` 中启用 `TEST_SIGNED` 后才会测试有符号及混合符号操作数。
* **全量测试**：在 `menuconfig` 中启用 `TEST_EXHAUSTIVE` 后，将遍历所有输入组合，适合位宽较小的穷举验证。

## 自定义测试（学生接口）
默认的 `builtin` 测试之外，可以在 `student/tests/custom_tests.cpp` 中实现 `customTests()`，用自己构造的数据或方法驱动设计；所有经 `tb` 发出的请求都会自动与参考模型比对。

```bash
make test SUITE=custom                                   # 只跑自定义测试
make test SUITE=all                                      # 内置 + 自定义
make test SUITE=custom VECTORS=student/tests/vectors.txt # 从文件加载测试向量
```

可用接口（均在 `namespace sim`，头文件 `sim/student.h`）：
* **数据**：`Request{a, b, aSigned = 0, bSigned = 0}`、`directedRequests()`、`randomRequests(n, rng)`、`loadRequests(file)`（每行 `a b [aSigned bSigned]`，支持 `#` 注释）、`filterEnabled(requests)`。
* **驱动**：`tb.run(requests, Pacing)` 按自定义的发送/接收停顿模式发送（`Pacing::always()`、`Pacing::random(rng)`，或自行设置 `offer` / `ready` 回调）；`tb.step(request, ready)` 逐周期控制；`tb.reset()`、`tb.drain()`、`tb.resetDuringTraffic(r)`。
* **常量**：`width`、`testSigned`、`operandMask`。

`Request` 始终保留操作数的低 `width` 位。非负数可提供任意能放进该位宽的位模式；负数按二补码判断，丢掉的如果只是符号扩展位就不警告。以 8 位为例，`-1`、`-128`、`255` 都不会警告，`-129` 和 `256` 则会警告。`aSigned` / `bSigned` 只决定乘法时如何解释位模式，不影响这项检查。

* 普通构造 `Request{a, b}`：默认的 GCC/Clang 优化构建会对编译器能识别的越界常量发出编译警告；对运行时才知道的值，警告写入 `stderr`，并显示原值和截断结果。两种情况都不会停止测试。
* 需要保证在编译期检查（例如初始化 `constexpr` 对象，或关闭了优化）时，用 `Request::constant<A, B>(aSigned, bSigned)`。例如 `constexpr auto r = Request::constant<-129, 1>();` 在 8 位下会产生编译警告，`r.a` 仍是 `0x7f`。

`sim/` 目录结构：`rtl/Multiplier.sv`（测试适配器）、`main.cpp` / `main.h`（入口与命令行选项）、`model.*`（请求与参考模型）、`testbench.*`（驱动与记分板）、`testgen.*`（数据生成/加载）、`builtin_tests.*`（内置测试）、`progress.*`（穷举进度）、`config.h`（编译期参数）。

---

## 附录：端口、时序与接口约定

### 模块端口
Verilog 模块名即 `IMPL_MODULE`，参数 `WIDTH`（固定延迟实现另有 `LATENCY`）；Chisel 模块端口与之相同（时序模块使用隐式 `clock`/同步 `reset`）。

| 实现类型 | 端口 |
| :--- | :--- |
| 组合（`IMPL_CLOCKED=0`） | `a`、`b`（WIDTH 位输入），`product`（2×WIDTH 位输出） |
| 固定延迟（`IMPL_FIXED_CYCLE=1`） | `clock`、`reset`，加上述 `a`、`b`、`product` |
| 握手（`IMPL_HANDSHAKE=1`） | `clock`、`reset`、`a`、`b`、`product`，以及 `in_valid`、`in_ready`、`out_valid`、`out_ready` |
| 有符号（`IMPL_SIGNED=1`） | 握手端口再加 `a_signed`、`b_signed` |

### 时序约定
*   **固定多周期（`IMPL_FIXED_CYCLE=1` 且 `IMPL_PIPELINED=0`）**：假设模块在复位后第 1, L+1, 2L+1... 个上升沿采样输入，在第 L, 2L, 3L... 个上升沿之后输出结果（L 为 `LATENCY`）。学员需遵守该采样节拍。
*   **固定延迟流水线（`IMPL_FIXED_CYCLE=1` 且 `IMPL_PIPELINED=1`）**：每拍采样输入，经过 L 个上升沿后结果可用，允许每拍一组输入。
*   **握手（`IMPL_HANDSHAKE=1`）**：仅在 `in_valid && in_ready` 的上升沿接收请求、在 `out_valid && out_ready` 的上升沿取走结果；结果须按请求顺序返回；复位应取消在途请求。
*   **其他**：时序实现均使用 `clock` 上升沿与同步高有效 `reset`。
