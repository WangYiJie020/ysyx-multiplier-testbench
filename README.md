# YSYX 乘法器教学 Testbench

Makefile 管理原生 Kconfig → Mill/Chisel → Verilator → C++ 自检。
默认使用 **8 位、Chisel、组合逻辑阶段**，含符号测试默认关闭。
各阶段示例均以直接 `*` 计算乘积，供学员逐步替换实现。

## 环境与初始化

需要 Git、GNU Make >= 4.3、C/C++17 编译器（支持 `unsigned __int128`）、flex、bison、
ncurses 开发包、Mill launcher、系统 JDK、Verilator 5.x。
Mill 固定为 1.1.6，Scala 2.13.18，Chisel/compiler plugin 7.4.0。

```sh
bash init.sh                 # 从固定版本的 NEMU 拉取 tools/kconfig；构建时也会自动初始化
make menuconfig              # NEMU 原生 mconf/lxdialog 菜单
make                         # 构建并执行自检
make test TESTS=100000 SEED=42 TIMEOUT=20000
make wave                    # 同时生成 FST
make rtl                     # 仅生成 RTL
make sim                     # 仅构建仿真器
make regression TESTS=1000    # 双语言、五阶段与固定延迟边界回归
make defconfig               # 恢复默认配置（8 位组合 Chisel）
make defconfig DEFCONFIG=configs/verilog_defconfig
make savedefconfig DEFCONFIG=configs/my_defconfig
make olddefconfig            # 修改 .config 后补全原生配置
make clean                   # 清理 build
make distclean               # 额外清理 Mill out 与当前配置
```


可覆盖工具变量 `MILL/MILL_FLAGS/VERILATOR/VERILATOR_FLAGS/CXX/JOBS`，以及运行时
`TESTS/SEED/TIMEOUT/SIM_ARGS`；硬件参数在 menuconfig 中设置。
`make regression` 临时顺序切换 `.config`，退出时恢复原配置，请勿与其他构建同时运行。

## 五个教学阶段

| 阶段 | 学员数据端口 | 时钟/复位 | 握手 | 符号开关 | Verilog 文件 |
| --- | --- | --- | --- | --- | --- |
| 1 组合逻辑 | a, b, product | 无 | 无 | 无 | `CombMultiplier.v` |
| 2 固定多周期 FSM | a, b, product | 有 | 无 | 无 | `MulticycleMultiplier.v` |
| 3 固定延迟流水线 | a, b, product | 有 | 无 | 无 | `PipelineMultiplier.v` |
| 4 引入握手 | a, b, product | 有 | in_valid/in_ready/out_valid/out_ready | 无 | `HandshakeMultiplier.v` |
| 5 支持符号 | a, b, product | 有 | 完整握手 | a_signed/b_signed | `SignedMultiplier.v` |


`a/b` 为 WIDTH 位，`product` 为 2×WIDTH 位完整乘积。
时序阶段使用 `clock` 上升沿与同步高有效 `reset`。

使用 Chisel 的学员实现应修改 `multiplier/src/multiplier/Students.scala` 中对应类；
使用 Verilog 学员应修改 `student/rtl/` 中对应文件，保留模块名和端口。
每个阶段使用独立的 Verilog 文件，Chisel BlackBox **只加载所选阶段文件**。
Verilog 模块都有 WIDTH 参数；阶段 2/3 另有 LATENCY 参数。

下面是各个阶段的说明。

### 没有握手的阶段

## 阶段 1 是真正的组合模块，端口没有时钟、复位、有效位或符号开关。

对应讲义的
- 基于ROM的乘法器
- 纯组合逻辑

## 阶段 2 的 LATENCY=L（使用 `make menuconfig` 配置） 是学员状态机的固定计算周期数（不是额外添加的流水级）。
我们假设学员的模块在复位后第 1、L+1、2L+1……个上升沿采样输入，在第 L、2L、3L……个上升沿之后输出对应结果。
例如 L=3 时，第 1 拍取数，第 3 拍后结果可用，第 4 拍取下一组。

测试框架会使用与学员模块同相位的计数器调度请求；
学员应遵守该固定采样节拍，不需要有效位或完成信号。

对应讲义的
- 状态机
- 优化的状态机
- 移位加乘法器

## 阶段 3 流水化，每拍均采样操作数，经过 L 个上升沿后对应结果可用，允许每拍一组输入。
例如 L=1 时，采样该输入的上升沿之后即可看到结果。
框架独立跟踪有效请求并预留结果缓冲空间，测试侧背压不会导致流水中的有效结果丢失。

对应讲义的
- 流水线

LATENCY 仅在阶段 2/3 可配置（1–64），必须与学员实现相符。

### 有握手的阶段

阶段 4/5 仅在 `valid && ready` 的上升沿传输；背压时保持有效位和数据。
结果须按请求顺序返回，可自行选择固定/可变延迟和并发度；复位取消在途请求。
不再用 LATENCY 或框架流水线限定学员时序。
阶段 4 仅无符号；

阶段 5 每个请求可独立指定两个操作数的补码解释方式。即加入符号扩展，这部分为扩展挑战。

## C++ 测试与 RISC-V 语义

测试框架在学员模块之外适配各阶段，在 C++ 侧提供统一的请求/结果流。
阶段 1–3 的握手、时钟控制和结果缓存属于 testbench，不会增加学员模块的端口。
记分板根据实际传输记录请求并核对完整乘积，覆盖边界、随机数据、连续请求、
随机间隙、背压、超时、中途复位与重启；WIDTH<=4 时穷举符合测试开关的输入。

溢出以输出的 **2×WIDTH 位**为准。两个 WIDTH 位操作数的完整乘积始终能由该输出表示，
无符号、有符号和混合符号运算均不会溢出，因此没有溢出测试开关。
测试始终覆盖完整输入范围，不会因为乘积超过 WIDTH 位而过滤或缩小操作数；
例如 8 位无符号的 `255 × 255 = 65025` 属于正常的 16 位结果。
`TEST_SIGNED` 默认关闭，且仅在阶段 5 可开启；其他阶段始终只测试无符号。
开启后覆盖 signed×signed、signed×unsigned 和交换操作数的 unsigned×signed。
所有定向、随机和复位请求都遵守开关。

按 [RISC-V M 扩展](https://docs.riscv.org/reference/isa/v20240411/unpriv/m-st-ext.html)：
MUL 取低 WIDTH 位，MULHU/MULH/MULHSU 分别取无符号×无符号、
有符号×有符号、有符号×无符号完整乘积的高 WIDTH 位。乘法不产生溢出异常。
当前接口一起核对高低位，参考模型显式符号扩展并用 128 位无符号模运算，
避免依赖宿主机的有符号溢出或 x86 标志位。
WIDTH=32/64 对应 RV32/RV64，其余宽度按相同位向量规则推广，不模拟 MULW。

结果位于 `build/<language>-stage<n>-w<width>-l<latency>-s<signed>-e<exhaustive>/`，
包含生成的 RTL、Verilator 模型、`sim` 及可选 `wave.fst`。

### 强制全量测试

在 `make menuconfig` 中启用 `TEST_EXHAUSTIVE`（“Force exhaustive testing”），默认关闭。
开启后用逐个生成的全量输入替代常规定向/随机计算测试，不受 `TESTS` 数量限制；
保留背压和后续复位重启测试。无需保存全部输入，内存占用不随用例总数增长。
无符号模式共 `2^(2×WIDTH)` 个用例；阶段 5 同时开启 `TEST_SIGNED` 时，
遍历四种符号开关组合，共 `2^(2×WIDTH+2)` 个用例。
总数严格大于 `2^24` 时，在测试前输出警告；每实际核对完成 `2^20` 个全量用例使用 `\r` 原行刷新进度，
显示已完成数、总数及百分比，完成时显示 `100.00%` 并换行。请求已提交但结果未返回不计入完成进度。
总数和进度采用十进制字符串表示，支持 64 位操作数下最多 `2^130` 的精确计数。
