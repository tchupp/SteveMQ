defmodule Packet.Subscribe do
  use Bitwise
  require Logger

  alias Packet.Decode
  alias Packet.Encode2, as: Encode

  @type qos :: 0 | 1 | 2
  @type topic :: {binary(), qos}
  @type topics :: [topic]

  @opaque t :: %__MODULE__{
            packet_id: Packet.package_identifier(),
            topics: topics()
          }

  @opaque decode_result :: {:subscribe, t} | {:subscribe_error, String.t()}

  defstruct packet_id: nil,
            topics: []

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(<<8::4, 0::1, 0::1, 1::1, 0::1>>, <<packet_id::16, rest::binary>>) do
    {_properties_length, _prop_length_size, payload} = Decode.variable_length_prefixed(rest)

    {
      :subscribe,
      %Packet.Subscribe{
        topics: decode_topics(payload),
        packet_id: packet_id
      }
    }
  end

  defp decode_topics(<<>>), do: []

  defp decode_topics(<<length::16, rest::binary>>) do
    <<topic::binary-size(length), _flags::6, qos::2, rest::binary>> = rest

    case qos do
      3 -> [] ++ decode_topics(rest)
      _ -> [{topic, qos}] ++ decode_topics(rest)
    end
  end

  defimpl Packet.Encodable do
    def encode(
          %Packet.Subscribe{
            packet_id: packet_id,
            topics: [{<<_topic_filter::binary>>, _qos} | _]
          } = subscribe
        )
        when packet_id in 0x0001..0xFFFF do
      encoded_topics =
        for {topic_filter, qos} <- subscribe.topics,
            do: <<byte_size(topic_filter)::16, topic_filter::binary, 0::6, qos::2>>,
            into: <<>>

      encoded_properties = <<>>

      packet_length =
        2 +
          1 + byte_size(encoded_properties) +
          byte_size(encoded_topics)

      <<8::4, 0::1, 0::1, 1::1, 0::1>> <>
        Encode.variable_length_int(packet_length) <>
        <<packet_id::16>> <>
        <<0>> <>
        encoded_topics
    end
  end
end
