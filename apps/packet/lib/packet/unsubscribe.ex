defmodule Packet.Unsubscribe do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:unsubscribe, String.t()}

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(<<10::4, 2::4>>, _msg) do
    Logger.info("RECEIVED A UNSUBSCRIBE")
    {:unsubscribe, "unsubscribe reasons"}
  end
end
