package multiplier

import chisel3._
import chisel3.util._

// 流水线化移位加乘法器
// 将移位加乘法器展开为 WIDTH 级流水线，每级只经过一个加法器（讲义任务四，二选一）。LATENCY 固定为 WIDTH。
// 接口约定：固定延迟流水线：每个上升沿都采样 a/b，经过 L 个上升沿后 product 有效（L=LATENCY），允许每拍一组输入。
class PipelinedShiftAddMultiplier(w: Int, latency: Int) extends Module with RequireSyncReset {
  val io = FlatIO(new UnsignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  io.product := ShiftRegister(io.a * io.b, latency)
  // ==================== 缺省实现结束 ====================
}
