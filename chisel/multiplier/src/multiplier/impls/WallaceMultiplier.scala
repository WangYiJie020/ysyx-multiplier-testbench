package multiplier

import chisel3._
import chisel3.util._

// Wallace 树乘法器
// 用 CSA（3:2 压缩器）逐层压缩部分积，最后用一次 CPA 相加；要求流水线化，任意组合路径最多经过一个 CSA（讲义任务五）。
// LATENCY 可在 menuconfig 中调整，缺省为 CSA 层数 + 1。
// 接口约定：固定延迟流水线：每个上升沿都采样 a/b，经过 L 个上升沿后 product 有效（L=LATENCY），允许每拍一组输入。
class WallaceMultiplier(w: Int, latency: Int) extends Module with RequireSyncReset {
  val io = FlatIO(new UnsignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  io.product := ShiftRegister(io.a * io.b, latency)
  // ==================== 缺省实现结束 ====================
}
