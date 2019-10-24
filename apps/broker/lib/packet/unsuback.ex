defmodule Packet.Unsuback do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:unsuback, String.t()}

  @spec decode(<<_ :: 8>>, <<_ :: 24>>) :: decode_result
  def decode(<<11 :: 4, 2 :: 4>>, _msg) do
    Logger.info("RECEIVED A UNSUBSCRIBE")
    {:unsuback, "unsuback reasons"}
  end

end