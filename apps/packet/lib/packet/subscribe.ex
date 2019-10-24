defmodule Packet.Subscribe do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque decode_result :: {:subscribe, %{topic_filter: binary(), packet_id: binary()}}

  @spec decode(<<_ :: 8>>, binary()) :: decode_result
  def decode(<<8 :: 4, 2 :: 4>>, <<packet_id :: 16, rest :: binary>>) do
    {properties_length, _prop_length_size, rest} = Decode.variable_length_prefixed(rest)

    <<
      _properties :: binary - size(properties_length),
      topic_filter_length :: 16,
      topic_filter :: binary - size(topic_filter_length),
      _ :: binary
    >> = rest

    {
      :subscribe,
      %{
        topic_filter: topic_filter,
        packet_id: packet_id
      }
    }
  end

end