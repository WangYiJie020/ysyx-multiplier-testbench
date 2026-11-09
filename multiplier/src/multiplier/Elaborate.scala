package multiplier

import circt.stage.ChiselStage

object Elaborate {
  def main(args: Array[String]): Unit = {
    require(args.length == 5, "usage: <width> <stage> <latency> <chisel|verilog> <target-dir>")
    val p = MulParams(args(0).toInt, Stage.fromId(args(1).toInt), args(2).toInt, args(3) == "verilog")
    ChiselStage.emitSystemVerilogFile(new Multiplier(p),
      args = Array("--target-dir", args(4)),
      firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info"))
  }
}
