# 流水线化移位加乘法器
# 接口/时序描述，供 Makefile 与测试适配器使用（说明见 README「描述一种新实现」）。
IMPL_TITLE := 流水线化移位加乘法器
IMPL_MODULE := PipelinedShiftAddMultiplier
IMPL_CLOCKED := 1
IMPL_FIXED_CYCLE := 1
IMPL_PIPELINED := 1
IMPL_HANDSHAKE := 0
IMPL_SIGNED := 0
IMPL_MAX_WIDTH := 64
IMPL_LATENCY_CONFIGURABLE := 0
IMPL_DEFAULT_LATENCY = $(WIDTH)
