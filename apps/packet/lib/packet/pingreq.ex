defmodule Packet.Pingreq do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:pingreq}

  @spec decode(<<_::8>>, <<_::8>>) :: decode_result
  def decode(<<12::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PINGREQ")
    {:pingreq}
  end
end
