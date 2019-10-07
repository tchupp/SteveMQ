defmodule Packet.Decode do
  require Logger

  def parse(msg) do
    case msg do
      <<01::4, 0::4, _::binary>> -> parse_connect(msg)
      <<02::4, 0::4, _::binary>> -> parse_connack(msg)
      <<03::4, _::4, _::binary>> -> parse_publish(msg)
      <<04::4, 0::4, _::binary>> -> parse_puback(msg)
      <<05::4, 0::4, _::binary>> -> parse_pubrec(msg)
      <<06::4, 2::4, _::binary>> -> parse_pubrel(msg)
      <<07::4, 0::4, _::binary>> -> parse_pubcomp(msg)
      <<08::4, 2::4, _::binary>> -> parse_subscribe(msg)
      <<09::4, 0::4, _::binary>> -> parse_suback(msg)
      <<10::4, 2::4, _::binary>> -> parse_unsubscribe(msg)
      <<11::4, 0::4, _::binary>> -> parse_unsuback(msg)
      <<12::4, 0::4, _::binary>> -> parse_pingreq(msg)
      <<13::4, 0::4, _::binary>> -> parse_pingres(msg)
      <<14::4, 0::4, _::binary>> -> parse_disconnect(msg)
      _ -> {:error, "could not determine packet type from: #{msg}"}
    end
  end

  defp parse_connect(msg) do
    <<_packet_type, rest::binary>> = msg
    {_remaining_length, _rem_length_size, rest} = parse_variable_int(rest)

    <<protocol_length::16, rest::binary>> = rest
    <<_protocol::binary-size(protocol_length), rest::binary>> = rest
    <<protocol_level, rest::binary>> = rest
    <<connect_flags, rest::binary>> = rest
    <<keep_alive::16, rest::binary>> = rest
    {props_length, _props_length_size, rest} = parse_variable_int(rest)
    <<_properties::binary-size(props_length), rest::binary>> = rest

    <<client_id_length::16, rest::binary>> = rest
    <<client_id::binary-size(client_id_length)>> = rest

    {:connect,
     %{
       :client_id => client_id,
       :connect_flags => connect_flags,
       :keep_alive => keep_alive,
       :protocol_level => protocol_level
     }}
  end

  defp parse_connack(_msg) do
    Logger.info("RECEIVED A CONNACK")
    {:error, "connack reasons"}
  end

  defp parse_subscribe(msg) do
    <<_, rest::binary>> = msg
    {_remaining_length, _rem_length_size, rest} = parse_variable_int(rest)
    <<packet_id::16, rest::binary>> = rest
    {properties_length, _prop_length_size, rest} = parse_variable_int(rest)
    <<_properties::binary-size(properties_length), rest::binary>> = rest
    <<topic_filter_length::16, rest::binary>> = rest
    <<topic_filter::binary-size(topic_filter_length), _::binary>> = rest

    {:subscribe,
     %{
       :topic_filter => topic_filter,
       :packet_id => packet_id
     }}
  end

  defp parse_suback(_msg) do
    Logger.info("RECEIVED A suback")
    {:error, "suback reasons"}
  end

  defp parse_publish(msg) do
    <<_, rest::binary>> = msg
    {remaining_length, _rem_length_size, rest} = parse_variable_int(rest)
    <<topic_length::16, rest::binary>> = rest
    <<topic::binary-size(topic_length), rest::binary>> = rest
    {properties_length, props_length_size, rest} = parse_variable_int(rest)

    msg_length = remaining_length - 2 - topic_length - properties_length - props_length_size

    message =
      case rest do
        <<msg::binary-size(msg_length)>> -> msg
        <<msg::binary-size(msg_length), _::binary>> -> msg
      end

    {:publish,
     %{
       :topic => topic,
       :message => message
     }}
  end

  defp parse_puback(_msg) do
    Logger.info("RECEIVED A PUBACK")
    {:error, "puback reasons"}
  end

  defp parse_pubrec(_msg) do
    Logger.info("RECEIVED A PUBREC")
    {:error, "pubrec reasons"}
  end

  defp parse_pubrel(_msg) do
    Logger.info("RECEIVED A PUBREL")
    {:error, "pubrel reasons"}
  end

  defp parse_pubcomp(_msg) do
    Logger.info("RECEIVED A PUBCOMP")
    {:error, "pubcomp reasons"}
  end

  defp parse_unsubscribe(_msg) do
    Logger.info("RECEIVED A UNSUBSCRIBE")
    {:error, "unsubscribe reasons"}
  end

  defp parse_unsuback(_msg) do
    Logger.info("RECEIVED A UNSUBACK")
    {:error, "unsuback reasons"}
  end

  defp parse_pingreq(_msg) do
    Logger.info("RECEIVED A PINGREQ")
    {:error, "pingreq reasons"}
  end

  defp parse_pingres(_msg) do
    Logger.info("RECEIVED A PINGRES")
    {:error, "pingres reasons"}
  end

  defp parse_disconnect(_msg) do
    Logger.info("RECEIVED A DISCONNECT")
    {:disconnect, "disconnect reasons"}
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
end
