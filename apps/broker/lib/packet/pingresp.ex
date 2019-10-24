defmodule Packet.Pingresp do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:pingresp}

  @spec decode(<<_ :: 8>>, <<_ :: 8>>) :: decode_result
  def decode(<<13 :: 4, 0 :: 4>>, <<0 :: 8>>) do
    Logger.info("RECEIVED A PINGRESP")
    {:pingresp, "pingresp reasons"}
  end

end