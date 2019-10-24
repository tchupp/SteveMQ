defmodule Packet.Encode do
  require Logger

  def connect(client_id, clean_start) do
    client_id_length = byte_size(client_id)
    remaining_length = client_id_length + 13
    connect_flags = case clean_start do
      true -> 2
      false -> 0
    end

    <<16, remaining_length, 0, 4, "MQTT", 5, 0, 0, 60>> <>
    <<connect_flags>> <>
    <<0, client_id_length>> <> client_id
  end

  def connack(:error) do
    <<2 :: 4, 0 :: 4>> <> <<3, 0, 0, 131>>
  end

  def puback(packet_id) do
    packet_type = <<4 :: 4, 0 :: 4>>
    remaining_length = <<4 :: 8>>
    reason_code = <<0 :: 8>>
    property_length = <<0 :: 8>>

    packet_type <> remaining_length <> <<packet_id :: 16>> <> reason_code <> property_length
  end

  def connack(session_present?: session_present?) do
    case session_present? do
      true -> <<32, 3, 1, 0, 0>>
      false -> <<32, 3, 0, 0, 0>>
    end
  end

  def subscribe(packet_id, topic_filter) do
    packet_type = <<8::4, 2::4>>
    filter_utf8 = utf8(topic_filter)
    remaining_length = <<(byte_size(filter_utf8) + 3)>>

    packet_type <> remaining_length <>
    <<packet_id::16, 0>> <>
    filter_utf8
  end

  def suback(packet_id) do
    packet_type = <<144>>
    remaining_length = <<3>>

    packet_type <> remaining_length <> <<packet_id :: 16, 0>>
  end

  def publish(topic, message) do
    packet_type = <<3 :: 4, 0 :: 4>>
    topic_utf8 = utf8(topic)
    properties_length = <<0>>
    variable_headers_and_payload = topic_utf8 <> properties_length <> message
    remaining_length = <<byte_size(variable_headers_and_payload)>>

    packet_type <> remaining_length <> variable_headers_and_payload
  end

  def pingresp() do
    <<13 :: 4, 0 :: 4, 0>>
  end

  def utf8(text) do
    text_length = byte_size(text)
    <<text_length :: 16>> <> text
  end
end
