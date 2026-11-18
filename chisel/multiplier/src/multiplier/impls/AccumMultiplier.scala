package multiplier

import chisel3._
import chisel3.util._

// 累加乘法器
// 状态机每周期用同一个加法器累加一个部分积，共 WIDTH 个周期（讲义任务二）。LATENCY 固定为 WIDTH。
// 接口约定：固定多周期：复位后第 1, L+1, 2L+1... 个上升沿采样 a/b，第 L, 2L, 3L... 个上升沿之后 product 有效（L=LATENCY）；采样之间不会送入新输入。
class AccumMultiplier(w: Int, latency: Int) extends Module with RequireSyncReset {
  val io = FlatIO(new UnsignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  val phase = RegInit(0.U(log2Ceil(latency + 1).W))
  val pending = Reg(UInt((2 * w).W))
  val result = Reg(UInt((2 * w).W))
  when(phase === 0.U) { pending := io.a * io.b }
  when(phase === (latency - 1).U) {
    result := (if (latency == 1) io.a * io.b else pending)
    phase := 0.U
  }.otherwise { phase := phase + 1.U }
  io.product := result
  // ==================== 缺省实现结束 ====================
}
