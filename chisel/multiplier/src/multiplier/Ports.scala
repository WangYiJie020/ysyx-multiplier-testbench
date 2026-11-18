package multiplier

import chisel3._

// Student-facing ports, flattened (FlatIO) so the generated Verilog module has exactly the ports
// a hand-written Verilog implementation has (`a`, `b`, `product`, ...). Combinational modules have
// no clock/reset; sequential ones use the ordinary implicit `clock` and synchronous `reset`.
class UnsignedPorts(w: Int) extends Bundle {
  val a = Input(UInt(w.W))
  val b = Input(UInt(w.W))
  val product = Output(UInt((2 * w).W))
}
class HandshakePorts(w: Int) extends UnsignedPorts(w) {
  val in_valid = Input(Bool())
  val in_ready = Output(Bool())
  val out_valid = Output(Bool())
  val out_ready = Input(Bool())
}
class SignedPorts(w: Int) extends HandshakePorts(w) {
  val a_signed = Input(Bool())
  val b_signed = Input(Bool())
}
