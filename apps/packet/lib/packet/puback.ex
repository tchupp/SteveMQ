defmodule Packet.Puback do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result ::
            {:puback, String.t()}
            | {:unknown, String.t()}

  @spec decode(<<_::8>>, <<_::24>>) :: decode_result
  def decode(<<04::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PUBACK")
    {:puback, "puback reasons"}
  end

  def decode(<<_header::8>>, <<rest::24>>) do
    {:unknown, ""}
  end
end
