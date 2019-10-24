defmodule Packet.Connect do
  use Bitwise
  require Logger

  alias Packet.Decode

  @opaque t :: %__MODULE__{
                 client_id: Package.client_id(),
                 username: binary() | nil,
                 password: binary() | nil,
                 protocol_level: non_neg_integer(),
                 clean_session: boolean(),
                 keep_alive: non_neg_integer(),
                 will: Package.Publish.t() | nil
               }

  @opaque decode_result :: {:connect, t}

  @enforce_keys [:client_id, :protocol_level, :clean_session, :keep_alive]
  defstruct client_id: nil,
            username: nil,
            password: nil,
            protocol_level: 0b00000101,
            clean_session: true,
            keep_alive: 60,
            will: nil

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(
        <<1::4, 0::4>>,
        <<4::16, "MQTT", protocol_level, username::1, password::1, will_retain::1, will_qos::2,
          will_present::1, clean_session::1, 0::1, keep_alive::16, rest::binary>>
      ) do
    {props_length, _props_length_size, rest} = Decode.variable_length_prefixed(rest)
    <<_properties::binary-size(props_length), rest::binary>> = rest

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
        clean_session: clean_session == 1,
        keep_alive: keep_alive,
        will:
          if will_present == 1 do
            %Packet.Publish{
              topic: options[:will_topic],
              message: options[:will_message],
              qos: will_qos,
              retain: will_retain == 1
            }
          end
      }
    }
  end

  def decode(<<_header::8>>, <<_rest::binary>>) do
    {:unknown, ""}
  end
end
