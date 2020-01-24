defmodule Packet.Pubcomp do
  use Bitwise
  require Logger

  @opaque decode_result :: {:pubcomp, String.t()}

  @spec decode(<<_::8>>, <<_::24>>) :: decode_result
  def decode(<<07::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PUBCOMP")
    {:pubcomp, "pubcomp reasons"}
  end
end
