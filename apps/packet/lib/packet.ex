defmodule Packet do
  use Bitwise

  alias Packet.Decode

  alias Packet.Connect
  alias Packet.Connack
  alias Packet.Publish
  alias Packet.Puback
  alias Packet.Pubrec
  alias Packet.Pubrel
  alias Packet.Pubcomp
  alias Packet.Subscribe
  alias Packet.Suback
  alias Packet.Unsubscribe
  alias Packet.Unsuback
  alias Packet.Pingreq
  alias Packet.Pingresp
  alias Packet.Disconnect

  @type client_id() :: String.t()

  @type packet_identifier() :: 0x0001..0xFFFF

  @type qos() :: 0..2

  @type topic() :: String.t()

  @type topic_filter() :: String.t()

  @type payload() :: binary() | nil

  @opaque message ::
            Packet.Connect.t()
            | Packet.Connack.t()
            | Packet.Disconnect.t()
            | Packet.Pingreq.t()
            | Packet.Pingresp.t()
            | Packet.Puback.t()
            | Packet.Pubcomp.t()
            | Packet.Publish.t()
            | Packet.Pubrec.t()
            | Packet.Pubrel.t()
            | Packet.Suback.t()
            | Packet.Subscribe.t()
            | Packet.Unsuback.t()
            | Packet.Unsubscribe.t()

  @opaque decode_result ::
            Packet.Connect.decode_result()
            | Packet.Connack.decode_result()
            | Packet.Disconnect.decode_result()
            | Packet.Pingreq.decode_result()
            | Packet.Pingresp.decode_result()
            | Packet.Puback.decode_result()
            | Packet.Pubcomp.decode_result()
            | Packet.Publish.decode_result()
            | Packet.Pubrec.decode_result()
            | Packet.Pubrel.decode_result()
            | Packet.Suback.decode_result()
            | Packet.Subscribe.decode_result()
            | Packet.Unsuback.decode_result()
            | Packet.Unsubscribe.decode_result()

  @spec decode(binary()) :: decode_result
  def decode(<<header::binary-size(1), data::binary>>) do
    {length, _size, data} = Decode.variable_length_prefixed(data)

    case data do
      <<payload::binary-size(length), _rest::binary>> -> parse_packet(header, payload)
      _ -> {:error, "could not determine packet type from: #{data}"}
    end
  end

  defp parse_packet(<<1::4, _::4>> = header, <<_::binary>> = payload),
    do: Connect.decode(header, payload)

  defp parse_packet(<<2::4, _::4>> = header, <<_::binary>> = payload),
    do: Connack.decode(header, payload)

  defp parse_packet(<<3::4, _::4>> = header, <<_::binary>> = payload),
    do: Publish.decode(header, payload)

  defp parse_packet(<<4::4, _::4>> = header, <<_::binary>> = payload),
    do: Puback.decode(header, payload)

  defp parse_packet(<<5::4, _::4>> = header, <<_::binary>> = payload),
    do: Pubrec.decode(header, payload)

  defp parse_packet(<<6::4, _::4>> = header, <<_::binary>> = payload),
    do: Pubrel.decode(header, payload)

  defp parse_packet(<<7::4, _::4>> = header, <<_::binary>> = payload),
    do: Pubcomp.decode(header, payload)

  defp parse_packet(<<8::4, _::4>> = header, <<_::binary>> = payload),
    do: Subscribe.decode(header, payload)

  defp parse_packet(<<9::4, _::4>> = header, <<_::binary>> = payload),
    do: Suback.decode(header, payload)

  defp parse_packet(<<10::4, _::4>> = header, <<_::binary>> = payload),
    do: Unsubscribe.decode(header, payload)

  defp parse_packet(<<11::4, _::4>> = header, <<_::binary>> = payload),
    do: Unsuback.decode(header, payload)

  defp parse_packet(<<12::4, _::4>> = header, <<_::binary>> = payload),
    do: Pingreq.decode(header, payload)

  defp parse_packet(<<13::4, _::4>> = header, <<_::binary>> = payload),
    do: Pingresp.decode(header, payload)

  defp parse_packet(<<14::4, _::4>> = header, <<_::binary>> = payload),
    do: Disconnect.decode(header, payload)

  defp parse_packet(<<header::8>>, <<_::binary>>),
    do: {:unknown, "unknown packet type. type=#{header}"}

  defdelegate encode(data), to: Packet.Encodable
end
