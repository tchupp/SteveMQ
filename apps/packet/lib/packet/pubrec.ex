defmodule Packet.Pubrec do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:pubrec, String.t()}

  @spec decode(<<_ :: 8>>, <<_ :: 24>>) :: decode_result
  def decode(<<05 :: 4, 0 :: 4>>, _msg) do
    Logger.info("RECEIVED A PUBREC")
    {:pubrec, "pubrec reasons"}
  end

end