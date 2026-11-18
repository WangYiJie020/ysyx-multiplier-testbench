package multiplier

import circt.stage.ChiselStage

/** Emits the student module (and any submodules) as one SystemVerilog file per module. */
object Elaborate {
  def main(args: Array[String]): Unit = {
    require(args.length == 4, "usage: <width> <impl-id> <latency> <target-dir>")
    ChiselStage.emitSystemVerilogFile(Impls.build(args(1), args(0).toInt, args(2).toInt),
      args = Array("--target-dir", args(3)),
      firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info"))
  }
}
