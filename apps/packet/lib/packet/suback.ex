defmodule Packet.Suback do
  use Bitwise
  require Logger

  alias Packet.Decode

  @type qos :: 0 | 1 | 2
  @type ack_result :: {:ok, qos} | {:error, :access_denied}

  @opaque t :: %__MODULE__{
            packet_id: Packet.packet_identifier(),
            acks: [ack_result]
          }

  @opaque decode_result :: {:suback, t} | {:suback_error, String.t()}

  @enforce_keys [:packet_id]
  defstruct packet_id: nil,
            acks: []

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(<<9::4, 0::4>>, <<packet_id::16, rest::binary>>) do
    {_properties_length, _prop_length_size, acks} = Decode.variable_length_prefixed(rest)

    {
      :suback,
      %Packet.Suback{
        packet_id: packet_id,
        acks: decode_acks(acks)
      }
    }
  end

  defp decode_acks(<<>>), do: []

  defp decode_acks(<<0x80::integer, acks::binary>>),
    do: [{:error, :access_denied}] ++ decode_acks(acks)

  defp decode_acks(<<ack::integer, acks::binary>>) when ack in 0x00..0x02,
    do: [{:ok, ack}] ++ decode_acks(acks)

  defp decode_acks(<<_ack::integer, acks::binary>>),
    do: [] ++ decode_acks(acks)

  defimpl Packet.Encodable do
    def encode(%Packet.Suback{packet_id: packet_id, acks: acks}) do
      properties_length = 0
      packet_length = 3 + length(acks)

      encoded_acks = acks |> Enum.map(fn ack -> encode_ack(ack) end)
      encoded_acks = for ack <- encoded_acks, do: <<ack::8>>, into: <<>>

      <<9::4, 0::4>> <>
        <<packet_length::8>> <>
        <<packet_id::16>> <>
        <<properties_length>> <>
        encoded_acks
    end

    defp encode_ack({:ok, qos}) when qos in 0x00..0x02, do: qos
    defp encode_ack({:error, _}), do: 0x80
  end
end
