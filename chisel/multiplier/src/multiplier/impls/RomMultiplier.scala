package multiplier

import chisel3._

// 基于 ROM 的乘法器
// 将 a、b 拼接成地址，查「乘法表」得到乘积（讲义第一节）。ROM 容量随位宽指数增长，位宽限制为 1~8。
// 接口约定：组合逻辑：无 clock/reset，product 须随 a/b 在同一周期给出。
class RomMultiplier(w: Int) extends RawModule {
  val io = FlatIO(new UnsignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  io.product := io.a * io.b
  // ==================== 缺省实现结束 ====================
}
