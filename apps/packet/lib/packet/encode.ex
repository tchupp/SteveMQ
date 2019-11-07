defmodule Packet.Encode do
  require Logger

  def connect(client_id, clean_start) do
    client_id_length = byte_size(client_id)
    remaining_length = client_id_length + 13

    connect_flags =
      case clean_start do
        true -> 2
        false -> 0
      end

    # connect flags
    # keep alive
    # properties length
    <<16, remaining_length, 0, 4, "MQTT", 5>> <>
      <<connect_flags>> <>
      <<0, 60>> <>
      <<0>> <>
      <<0, client_id_length>> <> client_id
  end

  def subscribe(packet_id, topic_filter) do
    packet_type = <<8::4, 2::4>>
    filter_utf8 = utf8(topic_filter)
    remaining_length = <<byte_size(filter_utf8) + 3>>

    packet_type <>
      remaining_length <>
      <<packet_id::16, 0>> <>
      filter_utf8
  end

  def suback(packet_id) do
    packet_type = <<144>>
    remaining_length = <<3>>

    packet_type <> remaining_length <> <<packet_id::16, 0>>
  end

  def pingresp() do
    <<13::4, 0::4, 0>>
  end

  def utf8(text) do
    text_length = byte_size(text)
    <<text_length::16>> <> text
  end
end
