package multiplier

import chisel3._
import chisel3.util._

// 有符号 A*B（握手接口）
// 在握手接口上额外支持有符号/混合符号操作数，缺省直接使用 `*`。启用 menuconfig 中的 TEST_SIGNED 才会测试符号组合。
// 接口约定：握手接口 + 符号控制：a_signed/b_signed 为 1 时对应操作数按有符号数解释（符号扩展后相乘），product 取 2*WIDTH 位完整乘积；握手约定同上。
class SignedDirectMultiplier(w: Int) extends Module with RequireSyncReset {
  val io = FlatIO(new SignedPorts(w))

  // ==================== 缺省实现开始 ====================
  // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
  // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
  val valid = RegInit(false.B)
  val result = Reg(UInt((2 * w).W))
  val a = Cat(io.a_signed && io.a(w - 1), io.a).asSInt
  val b = Cat(io.b_signed && io.b(w - 1), io.b).asSInt
  io.in_ready := (!valid || io.out_ready) && !reset.asBool
  io.out_valid := valid && !reset.asBool
  when(io.in_ready) {
    valid := io.in_valid
    when(io.in_valid) { result := (a * b).asUInt }
  }
  io.product := result
  // ==================== 缺省实现结束 ====================
}
