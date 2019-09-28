defmodule Broker.Packet do
  require Logger

  def parse(msg) do
    case msg do
      <<1::4, _::4, _::binary>> -> parse_connect(msg)
      _ -> {:error, "could not determine packet type"}
    end
  end

  defp parse_connect(msg) do
    case msg do
      <<_, remaining_length, _::binary>> when remaining_length > 127 ->
        {:not_implemented_connect, "can't handle >127 remaining lengths"}

      <<_, remaining_length, rest::binary>> when byte_size(rest) != remaining_length ->
        {:error, "remaining length is wrong"}

      <<_, _, protocol_length::16, protocol::64, _::binary>> when protocol_length != 4 ->
        {:not_implemented_connect, "protocol length bad: only supporting MQTT (size 4)"}

      <<_::9*8, connect_flags, _::binary>> when connect_flags != 2 and connect_flags != 1 ->
        {:not_implemented_connect, "only currently handling client id in CONNECT payload"}

      <<_, remaining_length, 0, 4, "M", "Q", "T", "T", protocol_level, connect_flags,
        keep_alive::16, client_id_length::16, client_id::binary>> ->
        {:connect,
         %{
           :client_id => client_id,
           :connect_flags => connect_flags,
           :keep_alive => keep_alive
         }}

      _ ->
        {:error, "could not parse CONNECT"}
    end
  end
end
