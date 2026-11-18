package multiplier

import chisel3._

/**
 * Chisel implementations by id (the ids of `impls/<id>.mk`). Interface/timing metadata lives in
 * those .mk files; here we only know how to build the module for a given width and latency.
 */
object Impls {
  val all: Map[String, (Int, Int) => RawModule] = Map(
    "direct" -> ((w, _) => new DirectMultiplier(w)),
    "rom" -> ((w, _) => new RomMultiplier(w)),
    "comb_add" -> ((w, _) => new CombAddMultiplier(w)),
    "accum" -> ((w, l) => new AccumMultiplier(w, l)),
    "shift_add" -> ((w, _) => new ShiftAddMultiplier(w)),
    "pipe_accum" -> ((w, l) => new PipelinedAccumMultiplier(w, l)),
    "pipe_shift_add" -> ((w, l) => new PipelinedShiftAddMultiplier(w, l)),
    "wallace" -> ((w, l) => new WallaceMultiplier(w, l)),
    "booth_wallace" -> ((w, l) => new BoothWallaceMultiplier(w, l)),
    "signed_direct" -> ((w, _) => new SignedDirectMultiplier(w)))

  def build(id: String, width: Int, latency: Int): RawModule =
    all.getOrElse(id, throw new IllegalArgumentException(
      s"unknown implementation '$id'; available: ${all.keys.toSeq.sorted.mkString(", ")}"))(width, latency)
}
