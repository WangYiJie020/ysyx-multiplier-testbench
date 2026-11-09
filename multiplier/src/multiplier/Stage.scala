package multiplier

/** Elaboration-time teaching stage; this is not a hardware-encoded state machine. */
sealed trait Stage
object Stage {
  case object Combinational extends Stage
  case object Multicycle extends Stage
  case object Pipeline extends Stage
  case object Handshake extends Stage
  case object Signed extends Stage

  // Numeric IDs are confined to the Kconfig/command-line boundary.
  def fromId(id: Int): Stage = id match {
    case 1 => Combinational
    case 2 => Multicycle
    case 3 => Pipeline
    case 4 => Handshake
    case 5 => Signed
    case other => throw new IllegalArgumentException(s"unknown teaching stage: $other")
  }
}
