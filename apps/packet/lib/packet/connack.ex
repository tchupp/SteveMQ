defmodule Packet.Connack do
  use Bitwise
  require Logger

  alias Packet.Decode

  @type status :: :accepted | {:refused, refusal_reasons()}
  @type refusal_reasons ::
          :unacceptable_protocol_version
          | :identifier_rejected
          | :server_unavailable
          | :bad_user_name_or_password
          | :not_authorized

  @opaque t :: %__MODULE__{
            session_present?: boolean(),
            status: status() | nil
          }

  @opaque decode_result :: {:connack, t} | {:connack_error, String.t()}

  @enforce_keys [:status]
  defstruct session_present?: false,
            status: nil

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(<<02::4, 0::4>>, <<0::7, session_present?::1, return_code::8, _rest::binary()>>)
      when return_code in 0x00..0x06,
      do: {
        :connack,
        %Packet.Connack{
          session_present?: session_present? == 1,
          status: decode_return_code(return_code)
        }
      }

  def decode(<<02::4, 0::4>>, <<0::7, _session_present?::1, return_code::8, _rest::binary()>>),
    do: {:connack_error, "unknown return_code. return_code=#{return_code}"}

  def decode(<<02::4, 0::4>>, <<_unknown_header::binary()>>),
    do: {:connack_error, "unknown variable_header"}

  @spec decode_return_code(<<_::8>>) :: status() | nil
  def decode_return_code(return_code) do
    case return_code do
      0x00 -> :accepted
      0x01 -> {:refused, :unacceptable_protocol_version}
      0x02 -> {:refused, :identifier_rejected}
      0x03 -> {:refused, :server_unavailable}
      0x04 -> {:refused, :bad_user_name_or_password}
      0x05 -> {:refused, :not_authorized}
    end
  end
end
