defmodule Packet.Decode do
  use Bitwise
  require Logger

  def decode(<<header::binary-size(1), 0::1, l1::7, data::binary>>) do
    length = l1

    parse(header, length, data)
  end

  def decode(<<header::binary-size(1), 1::1, l1::7, 0::1, l2::7, data::binary>>) do
    length = l1 + (l2 <<< 7)

    parse(header, length, data)
  end

  def decode(<<header::binary-size(1), 1::1, l1::7, 1::1, l2::7, 0::1, l3::7, data::binary>>) do
    length = l1 + (l2 <<< 7) + (l3 <<< 14)

    parse(header, length, data)
  end

  def decode(
        <<header::binary-size(1), 1::1, l1::7, 1::1, l2::7, 1::1, l3::7, 0::1, l4::7,
          data::binary>>
      ) do
    length = l1 + (l2 <<< 7) + (l3 <<< 14) + (l4 <<< 21)

    parse(header, length, data)
  end

  defp parse(header, length, data) do
    case data do
      <<payload::binary-size(length), _rest::binary>> -> parse_packet(header, payload)
      _ -> {:error, "could not determine packet type from: #{data}"}
    end
  end

  #  connect
  defp parse_packet(
         <<01::4, 0::4>>,
         <<4::16, "MQTT",
           protocol_level,
           username::1, password::1, will_retain::1, will_qos::2, will_present::1, clean_session::1, 0::1,
           keep_alive::16,
           rest::binary>>
       ) do
    {props_length, _props_length_size, rest} = parse_variable_int(rest)
    <<_properties :: binary - size(props_length), rest :: binary>> = rest

    options =
      [
        client_id: 1,
        will_topic: will_present,
        will_payload: will_present,
        username: username,
        password: password
      ]
      |> Enum.filter(fn {_, present} -> present == 1 end)
      |> Enum.map(fn {value, 1} -> value end)
      |> Enum.zip(decode_length_prefixed(rest))

    {
      :connect,
      %{
        client_id: options[:client_id],
        username: options[:username],
        password: options[:password],
        protocol_level: protocol_level,
        clean_session: clean_session == 1,
        keep_alive: keep_alive,
        will:
          if will_present == 1 do
            %{
              topic: options[:will_topic],
              payload: options[:will_payload],
              qos: will_qos,
              retain: will_retain == 1
            }
          end,
      }
    }
  end

  #  connack
  defp parse_packet(<<02::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A CONNACK")
    {:error, "connack reasons"}
  end

  #  publish
  defp parse_packet(
         <<03::4, _dup::1, _qos::integer-size(2), _retain::1>>,
         <<
           topic_length::big-integer-size(16),
           topic::binary-size(topic_length),
           rest::binary
         >>
       ) do
    {_properties_length, _props_length_size, message} = parse_variable_int(rest)

    {:publish,
     %{
       :topic => topic,
       :message => message
     }}
  end

  #  puback
  defp parse_packet(<<04::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PUBACK")
    {:error, "puback reasons"}
  end

  #  pubrec
  defp parse_packet(<<05::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PUBREC")
    {:error, "pubrec reasons"}
  end

  #  pubrel
  defp parse_packet(<<06::4, 2::4>>, _msg) do
    Logger.info("RECEIVED A PUBREL")
    {:error, "pubrel reasons"}
  end

  #  pubcomp
  defp parse_packet(<<07::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PUBCOMP")
    {:error, "pubcomp reasons"}
  end

  #  subscribe
  defp parse_packet(<<08::4, 2::4>>, <<packet_id::16, rest::binary>>) do
    {properties_length, _prop_length_size, rest} = parse_variable_int(rest)

    <<_properties::binary-size(properties_length), topic_filter_length::16,
      topic_filter::binary-size(topic_filter_length), _::binary>> = rest

    {:subscribe,
     %{
       :topic_filter => topic_filter,
       :packet_id => packet_id
     }}
  end

  #  suback
  defp parse_packet(<<09::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A SUBACK")
    {:error, "suback reasons"}
  end

  #  unsubscribe
  defp parse_packet(<<10::4, 2::4>>, _msg) do
    Logger.info("RECEIVED A UNSUBSCRIBE")
    {:error, "unsubscribe reasons"}
  end

  #  unsuback
  defp parse_packet(<<11::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A UNSUBACK")
    {:error, "unsuback reasons"}
  end

  #  pingreq
  defp parse_packet(<<12::4, 0::4>>, _msg) do
    Logger.info("RECEIVED A PINGREQ")
    {:pingreq}
  end

  #  pingres
  defp parse_packet(<<13::4, 0::4>>, _payload) do
    Logger.info("RECEIVED A PINGRES")
    {:error, "pingres reasons"}
  end

  #  disconnect
  defp parse_packet(<<14::4, 0::4>>, _payload) do
    Logger.info("RECEIVED A DISCONNECT")
    {:disconnect, "disconnect reasons"}
  end

  #  error
  defp parse_packet(header, _payload) do
    Logger.info("RECEIVED AN UNKNOWN PACKET. type: #{header}")
    {:unknown, "unknown packet type: #{header}"}
  end

  def parse_variable_int(bytes) do
    {int, num_bytes, rest} = parse_variable_int(bytes, 0, 0)
    {trunc(int), num_bytes, rest}
  end

  defp parse_variable_int(bytes, level, sum) do
    if level > 3 do
      raise "error parsing variable length int: encountered more than 4 bytes"
    end

    <<more_bytes?::1, current_byte_value::7, rest::binary>> = bytes
    multiplier = :math.pow(128, level)

    case more_bytes? do
      0 ->
        {current_byte_value * multiplier + sum, level + 1, rest}

      1 ->
        parse_variable_int(rest, level + 1, current_byte_value * multiplier + sum)
    end
  end

  defp decode_length_prefixed(<<>>), do: []

  defp decode_length_prefixed(<<length::big-integer-size(16), payload::binary>>) do
    <<item::binary-size(length), rest::binary>> = payload
    [item] ++ decode_length_prefixed(rest)
  end
end
