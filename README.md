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

---

## 附录：时序与接口约定

*   **阶段 2 (固定多周期)**：假设模块在复位后第 1, L+1, 2L+1... 个上升沿采样输入，在第 L, 2L, 3L... 个上升沿之后输出结果。学员需遵守该采样节拍。
*   **阶段 3 (流水线)**：每拍采样输入，经过 L 个上升沿后结果可用，允许每拍一组输入。
*   **阶段 4/5 (带握手)**：仅在 `valid && ready` 的上升沿传输；结果须按请求顺序返回；复位应取消在途请求。
*   **其他**：时序阶段均使用 `clock` 上升沿与同步高有效 `reset`。
