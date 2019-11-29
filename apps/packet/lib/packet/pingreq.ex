defmodule Packet.Pingreq do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque t :: %__MODULE__{}

  @opaque decode_result :: {:pingreq, t}

  @enforce_keys []
  defstruct []

  @spec decode(<<_::8>>, <<_::8>>) :: decode_result
  def decode(<<12::4, 0::4>>, _msg) do
    {:pingreq, %Packet.Pingreq{}}
  end

  defimpl Packet.Encodable do
    def encode(%Packet.Pingreq{}) do
      <<12::4, 0::4, 0::8>>
    end
  end
end
