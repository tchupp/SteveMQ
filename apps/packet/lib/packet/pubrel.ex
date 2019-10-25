defmodule Packet.Pubrel do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:pubrel, String.t()}

  @spec decode(<<_::8>>, <<_::24>>) :: decode_result
  def decode(<<06::4, 2::4>>, _msg) do
    Logger.info("RECEIVED A PUBREL")
    {:pubrel, "pubrel reasons"}
  end
end
