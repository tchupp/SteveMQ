defmodule Packet.Disconnect do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:disconnect, String.t()}

  @spec decode(<<_ :: 8>>, <<_ :: 8>>) :: decode_result
  def decode(<<14 :: 4, 0 :: 4>>, _payload) do
    Logger.info("RECEIVED A DISCONNECT")
    {:disconnect, "disconnect reasons"}
  end

end