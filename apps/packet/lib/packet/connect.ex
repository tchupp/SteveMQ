defmodule Packet.Connect do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque t :: %__MODULE__{
            client_id: Package.client_id(),
            username: binary() | nil,
            password: binary() | nil,
            protocol_level: non_neg_integer(),
            clean_start: boolean(),
            keep_alive: non_neg_integer(),
            will: Package.Publish.t() | nil,
            session_expiry: 0..2_147_483_647,
            receive_maximum: 0..65_535
          }

  @opaque decode_result :: {:connect, t} | {:connect_error, String.t()}

  @enforce_keys [:client_id, :clean_start]
  defstruct client_id: nil,
            username: nil,
            password: nil,
            protocol_level: 0b00000101,
            clean_start: true,
            keep_alive: 60,
            will: nil,
            session_expiry: 0,
            receive_maximum: 65_535

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(
        <<1::4, 0::4>>,
        <<4::16, "MQTT", protocol_level::8, username::1, password::1, will_retain::1, will_qos::2,
          will_present::1, clean_start::1, 0::1, keep_alive::16, rest::binary>>
      ) do
    {properties, rest} = decode_properties(rest)

    options =
      [
        client_id: 1,
        will_topic: will_present,
        will_message: will_present,
        username: username,
        password: password
      ]
      |> Enum.filter(fn {_, present} -> present == 1 end)
      |> Enum.map(fn {value, 1} -> value end)
      |> Enum.zip(Decode.fixed_length_prefixed(rest))

    {
      :connect,
      %Packet.Connect{
        client_id: options[:client_id],
        username: options[:username],
        password: options[:password],
        protocol_level: protocol_level,
        clean_start: clean_start == 1,
        keep_alive: keep_alive,
        will:
          if will_present == 1 do
            %Packet.Publish{
              topic: options[:will_topic],
              message: options[:will_message],
              qos: will_qos,
              retain: will_retain == 1
            }
          end,
        session_expiry: properties[:session_expiry],
        receive_maximum: properties[:receive_maximum]
      }
    }
  end

  def decode(<<_header::8>>, <<_rest::binary>>) do
    {:connect_error, ""}
  end

  defp decode_properties(<<bytes::binary>>) do
    {props_length, _props_length_size, rest} = Decode.variable_length_prefixed(bytes)
    <<properties::binary-size(props_length), rest::binary>> = rest

    default_properties = %{session_expiry: 0, receive_maximum: 65_535}
    {decode_properties(properties, default_properties), rest}
  end

  defp decode_properties(<<17::8, bytes::binary>>, properties) do
    <<session_expiry::32, bytes::binary>> = bytes
    decode_properties(bytes, %{properties | session_expiry: session_expiry})
  end

  defp decode_properties(<<33::8, bytes::binary>>, properties) do
    <<receive_maximum::16, bytes::binary>> = bytes
    decode_properties(bytes, %{properties | receive_maximum: receive_maximum})
  end

  defp decode_properties(_bytes, properties) do
    properties
  end
end
