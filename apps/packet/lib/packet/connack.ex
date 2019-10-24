defmodule Packet.Connack do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:connack, String.t()}

  @spec decode(<<_ :: 8>>, binary()) :: decode_result
  def decode(<<02 :: 4, 0 :: 4>>, _msg) do
    Logger.info("RECEIVED A CONNACK")
    {:connack, "connack reasons"}
  end

end