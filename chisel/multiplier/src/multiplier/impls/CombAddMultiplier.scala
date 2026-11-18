package multiplier

import chisel3._

// 组合逻辑部分积累加乘法器
// 按位与生成部分积、移位后用加法器全部相加，一个周期内完成（讲义任务一）。
// 接口约定：组合逻辑：无 clock/reset，product 须随 a/b 在同一周期给出。
class CombAddMultiplier(w: Int) extends RawModule {
  val io = FlatIO(new UnsignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  io.product := io.a * io.b
  // ==================== 缺省实现结束 ====================
}
