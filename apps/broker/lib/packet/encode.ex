defmodule Packet.Encode do
  require Logger

  def connack() do
    <<32, 3, 0, 0, 0>>
  end

  def connack(:error) do
    <<32, 3, 0, 0, 131>>
  end

  def suback(packet_id) do
    packet_type = <<144>>
    remaining_length = <<3>>

    packet_type <> remaining_length <> <<packet_id::16, 0>>
  end

  def publish(topic, message) do
    packet_type = <<3::4, 0::4>>
    topic_utf8 = utf8(topic)
    properties_length = <<0>>
    variable_headers_and_payload = topic_utf8 <> properties_length <> message
    remaining_length = <<byte_size(variable_headers_and_payload)>>

    packet_type <> remaining_length <> variable_headers_and_payload
  end

  def pingresp() do
    <<13::4, 0::4, 0>>
  end

  def utf8(text) do
    text_length = byte_size(text)
    <<text_length::16>> <> text
  end
end
