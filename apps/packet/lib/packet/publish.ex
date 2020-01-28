defmodule Packet.Publish do
  use Bitwise
  require Logger

  alias Packet.Decode
  alias Packet.Encode2, as: Encode

  @type publish_qos0 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 0,
          packet_id: nil,
          dup: false,
          retain: boolean()
        }
  @type publish_qos1 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 1,
          packet_id: Packet.packet_identifier(),
          dup: boolean(),
          retain: boolean()
        }
  @type publish_qos2 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 2,
          packet_id: Packet.packet_identifier(),
          dup: boolean(),
          retain: boolean()
        }

  @opaque decode_result ::
            {:publish_qos0, publish_qos0}
            | {:publish_qos1, publish_qos1}
            | {:publish_qos2, publish_qos2}
            | {:publish_error, String.t()}

  @enforce_keys [:topic, :message, :qos]
  defstruct topic: nil,
            message: nil,
            qos: nil,
            packet_id: nil,
            dup: false,
            retain: false

  @spec decode(<<_::8>>, binary()) :: decode_result

  #  publish - qos 0
  def decode(
        <<3::4, 0::1, 0::2, retain::1>>,
        <<
          topic_length::big-integer-size(16),
          topic::binary-size(topic_length),
          rest::binary
        >>
      ) do
    {_properties_length, _props_length_size, message} = Decode.variable_length_prefixed(rest)

    {
      :publish_qos0,
      %Packet.Publish{
        topic: topic,
        message: message,
        qos: 0,
        retain: retain == 1
      }
    }
  end

  def decode(<<3::4, _dup::1, 3::integer-size(2), _retain::1>>, <<_rest::binary>>) do
    {:publish_error, "unsupported qos. qos=3"}
  end

  #  publish - qos 1/2
  def decode(
        <<3::4, dup::1, qos::integer-size(2), retain::1>>,
        <<
          topic_length::big-integer-size(16),
          topic::binary-size(topic_length),
          packet_id::16,
          rest::binary
        >>
      ) do
    {_properties_length, _props_length_size, message} = Decode.variable_length_prefixed(rest)

    publish_type =
      case qos do
        1 -> :publish_qos1
        2 -> :publish_qos2
      end

    {
      publish_type,
      %Packet.Publish{
        topic: topic,
        message: message,
        qos: qos,
        packet_id: packet_id,
        dup: dup == 1,
        retain: retain == 1
      }
    }
  end

  def decode(<<3::4, _dup::1, _qos::integer-size(2), _retain::1>>, <<rest::binary>>) do
    {:publish_error, byte_size(rest)}
  end

  defimpl Packet.Encodable do
    def encode(%Packet.Publish{packet_id: nil, qos: 0} = publish) do
      <<3::4, 0::1, 0::2, flag(publish.retain)::1>> <>
        Encode.variable_length_prefixed(
          Encode.fixed_length_prefixed(publish.topic) <>
            Encode.variable_length_prefixed(<<>>) <>
            encode_message(publish)
        )
    end

    def encode(%Packet.Publish{packet_id: packet_id, qos: qos} = publish)
        when packet_id in 0x0001..0xFFFF do
      <<3::4, flag(publish.dup)::1, qos::2, flag(publish.retain)::1>> <>
        Encode.variable_length_prefixed(
          Encode.fixed_length_prefixed(publish.topic) <>
            <<packet_id::16>> <>
            Encode.variable_length_prefixed(<<>>) <>
            encode_message(publish)
        )
    end

    defp encode_message(%Packet.Publish{message: nil}), do: ""
    defp encode_message(%Packet.Publish{message: payload}), do: payload

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
