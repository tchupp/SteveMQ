defmodule Packet.Pingresp do
  use Bitwise
  require Logger

  @opaque t :: %__MODULE__{}

  @opaque decode_result :: {:pingresp, t}

  @enforce_keys []
  defstruct []

  @spec decode(<<_::8>>, <<_::8>>) :: decode_result
  def decode(<<13::4, 0::4>>, _msg) do
    {:pingresp, %Packet.Pingresp{}}
  end

  defimpl Packet.Encodable do
    def encode(%Packet.Pingresp{} = _) do
      <<13::4, 0::4, 0::8>>
    end
  end
end
