package multiplier

import chisel3._
import chisel3.util._

// 移位加乘法器
// 每周期根据乘数最低位决定是否累加，随后被乘数左移、乘数右移，乘数为 0 即可提前结束，因此延迟不固定，使用握手接口（讲义任务三）。
// 接口约定：握手接口：仅在 in_valid && in_ready 的上升沿接收请求，仅在 out_valid && out_ready 的上升沿取走结果；结果按请求顺序返回，复位取消在途请求。
class ShiftAddMultiplier(w: Int) extends Module with RequireSyncReset {
  val io = FlatIO(new HandshakePorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  val valid = RegInit(false.B)
  val result = Reg(UInt((2 * w).W))
  io.in_ready := (!valid || io.out_ready) && !reset.asBool
  io.out_valid := valid && !reset.asBool
  when(io.in_ready) {
    valid := io.in_valid
    when(io.in_valid) { result := io.a * io.b }
  }
  io.product := result
  // ==================== 缺省实现结束 ====================
}
