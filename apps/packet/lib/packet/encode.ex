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
end
