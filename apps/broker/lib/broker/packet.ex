defmodule Broker.Packet do
  require Logger

  def parse(msg) do
    case msg do
      <<1::4, 0::4, _::binary>> -> parse_connect(msg)
      <<3::4, _::4, _::binary>> -> parse_publish(msg)
      <<8::4, 2::4, _::binary>> -> parse_subscribe(msg)
      _ -> {:error, "could not determine packet type"}
    end
  end

  defp parse_connect(msg) do
    <<_packet_type, rest::binary>> = msg
    <<_remaining_length, rest::binary>> = rest

    <<protocol_length::16, rest::binary>> = rest
    <<protocol::binary-size(protocol_length), rest::binary>> = rest
    <<protocol_level, rest::binary>> = rest
    <<connect_flags, rest::binary>> = rest
    <<keep_alive::16, rest::binary>> = rest
    <<props_length, rest::binary>> = rest
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

  defp parse_subscribe(msg) do
    <<_, rest::binary>> = msg
    <<_remaining_length, rest::binary>> = rest
    <<_packet_id::16, rest::binary>> = rest
    <<topic_filter_length::16, rest::binary>> = rest
    <<topic::binary-size(topic_filter_length), rest::binary>> = rest

    Logger.info("SUBSCRIBE info: #{topic_filter_length}")

    {:subscribe,
     %{
       :topic => topic
     }}
  end

  defp parse_publish(msg) do
    <<_, rest::binary>> = msg
    <<_remaining_length, rest::binary>> = rest
    <<topic_length::16, rest::binary>> = rest
    <<topic::binary-size(topic_length), rest::binary>> = rest
    # skipping tons of other possible things to parse

    {:publish,
     %{
       :topic => topic,
       :message => rest
     }}
  end
end
