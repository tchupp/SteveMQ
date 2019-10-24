defmodule Packet.Suback do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:suback, String.t()}

  @spec decode(<<_ :: 8>>, binary()) :: decode_result
  def decode(<<9 :: 4, 0 :: 4>>, _msg) do
    Logger.info("RECEIVED A SUBACK")
    {:suback, "suback reasons"}
  end

end