defmodule Packet.Connect do
  use Bitwise
  require Logger

  alias Packet.Decode
  alias Packet.Encode2, as: Encode

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

  @session_expiry_id 17
  defp decode_properties(<<@session_expiry_id::8, bytes::binary>>, properties) do
    <<session_expiry::32, bytes::binary>> = bytes
    decode_properties(bytes, %{properties | session_expiry: session_expiry})
  end

  @receive_maximum_id 33
  defp decode_properties(<<@receive_maximum_id::8, bytes::binary>>, properties) do
    <<receive_maximum::16, bytes::binary>> = bytes
    decode_properties(bytes, %{properties | receive_maximum: receive_maximum})
  end

  defp decode_properties(_bytes, properties) do
    properties
  end

  defimpl Packet.Encodable do
    defp connection_flags(%Packet.Connect{will: nil} = c),
      do: <<
        flag(c.username)::1,
        flag(c.password)::1,
        flag(false)::1,
        0::2,
        flag(false)::1,
        flag(c.clean_start)::1,
        0::1
      >>

    defp connection_flags(%Packet.Connect{will: %Packet.Publish{} = will} = c),
      do: <<
        flag(c.username)::1,
        flag(c.password)::1,
        flag(will.retain)::1,
        will.qos::2,
        flag(will)::1,
        flag(c.clean_start)::1,
        0::1
      >>

    defp properties(%Packet.Connect{} = c) do
      Encode.variable_length_prefixed(
        <<17, c.session_expiry::32>> <>
          <<33, c.receive_maximum::16>>
      )
    end

    defp payload(%Packet.Connect{} = c) do
      [
        client_id: c.client_id,
        will_topic: c |> struct_get(:will) |> struct_get(:topic),
        will_message: c |> struct_get(:will) |> struct_get(:message),
        username: c.username,
        password: c.password
      ]
      |> Enum.map(fn {_key, value} -> value end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn value -> encode_atom(value) end)
      |> Enum.map(&Encode.fixed_length_prefixed/1)
      |> Enum.reduce(<<>>, fn next, acc -> acc <> next end)
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1

    defp struct_get(nil, _key), do: nil
    defp struct_get(struct, key), do: Map.get(struct, key)

    defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)
    defp encode_atom(atom), do: atom

    def encode(
          %Packet.Connect{
            protocol_level: protocol_level,
            keep_alive: keep_alive
          } = connect
        ) do
      <<1::4, 0::4>> <>
        Encode.variable_length_prefixed(
          <<4::16, "MQTT", protocol_level::8>> <>
            connection_flags(connect) <>
            <<keep_alive::16>> <>
            properties(connect) <>
            payload(connect)
        )
    end
  end
end
