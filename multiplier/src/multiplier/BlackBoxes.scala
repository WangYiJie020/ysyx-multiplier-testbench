package multiplier

import chisel3._
import chisel3.util.HasBlackBoxPath
import java.nio.file.Paths

abstract class StudentBlackBox(p: MulParams, name: String, timed: Boolean)
    extends BlackBox(if (timed) Map("WIDTH" -> p.width, "LATENCY" -> p.latency)
                    else Map("WIDTH" -> p.width)) with HasBlackBoxPath {
  override def desiredName: String = name
  addPath(Paths.get("student/rtl", name + ".v").toAbsolutePath.toString)
}
// Explicit clocks belong to the Verilog boundary; student Chisel Modules use
// their ordinary implicit clock/reset ports.
trait ClockResetPorts {
  val clock: Clock
  val reset: Bool
}
class TimedPorts(w: Int) extends UnsignedPorts(w) with ClockResetPorts {
  val clock = Input(Clock())
  val reset = Input(Bool())
}
class ClockedHandshakePorts(w: Int) extends HandshakePorts(w) with ClockResetPorts {
  val clock = Input(Clock())
  val reset = Input(Bool())
}
class ClockedSignedPorts(w: Int) extends SignedPorts(w) with ClockResetPorts {
  val clock = Input(Clock())
  val reset = Input(Bool())
}
class CombBlackBox(p: MulParams) extends StudentBlackBox(p, "CombMultiplier", false) {
  val io = IO(new UnsignedPorts(p.width))
}
class TimedBlackBox(p: MulParams) extends StudentBlackBox(p,
    if (p.stage == Stage.Multicycle) "MulticycleMultiplier" else "PipelineMultiplier", true) {
  val io = IO(new TimedPorts(p.width))
}
class HandshakeBlackBox(p: MulParams) extends StudentBlackBox(p, "HandshakeMultiplier", false) {
  val io = IO(new ClockedHandshakePorts(p.width))
}
class SignedBlackBox(p: MulParams) extends StudentBlackBox(p, "SignedMultiplier", false) {
  val io = IO(new ClockedSignedPorts(p.width))
}
