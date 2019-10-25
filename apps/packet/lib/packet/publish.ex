defmodule Packet.Publish do
  use Bitwise
  require Logger

  alias Packet.Decode

  @type publish_qos0 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 0,
          identifier: nil,
          dup: false,
          retain: boolean()
        }
  @type publish_qos1 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 1,
          identifier: Packet.package_identifier(),
          dup: boolean(),
          retain: boolean()
        }
  @type publish_qos2 :: %__MODULE__{
          topic: Packet.topic(),
          message: Packet.payload(),
          qos: 2,
          identifier: Packet.package_identifier(),
          dup: boolean(),
          retain: boolean()
        }

  @opaque decode_result ::
            {:publish_qos0, publish_qos0}
            | {:publish_qos1, publish_qos1}
            | {:publish_qos2, publish_qos2}
            | {:unknown, String.t()}

  @enforce_keys [:topic, :message, :qos, :retain]
  defstruct topic: nil,
            message: nil,
            qos: nil,
            identifier: nil,
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
      %{
        topic: topic,
        message: message,
        retain: retain == 1
      }
    }
  end

  #  publish - qos 1/2
  def decode(
        <<3::4, dup::1, qos::integer-size(2), retain::1>>,
        <<
          topic_length::big-integer-size(16),
          topic::binary-size(topic_length),
          rest::binary
        >>
      )
      when qos in 1..2 do
    <<packet_id::16, rest::binary>> = rest
    {_properties_length, _props_length_size, message} = Decode.variable_length_prefixed(rest)

    publish_type =
      case qos do
        1 -> :publish_qos1
        2 -> :publish_qos2
      end

    {
      publish_type,
      %{
        topic: topic,
        message: message,
        packet_id: packet_id,
        dup: dup == 1,
        retain: retain == 1
      }
    }
  end

  def decode(<<_header::8>>, <<_rest::binary>>) do
    {:unknown, ""}
  end
end
