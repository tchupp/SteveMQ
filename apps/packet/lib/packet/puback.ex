defmodule Packet.Puback do
  use Bitwise
  require Logger

  alias Packet.Decode

  @type status :: {:accepted, accept_reasons()} | {:refused, refusal_reasons()}
  @type accept_reasons ::
          :ok
          | :no_matching_subscribers
  @type refusal_reasons ::
          :unacceptable_protocol_version
          | :identifier_rejected
          | :server_unavailable
          | :bad_user_name_or_password
          | :not_authorized

  @opaque t :: %__MODULE__{
            packet_id: Packet.packet_identifier()
          }

  @opaque decode_result ::
            {:puback, t}
            | {:puback_error, String.t()}

  @enforce_keys [:packet_id, :status]
  defstruct packet_id: nil,
            status: nil

  @spec decode(<<_::8>>, binary()) :: decode_result
  def decode(<<4::4, 0::4>>, <<packet_id::16>>)
      when packet_id in 0x0001..0xFFFF,
      do: {
        :puback,
        %Packet.Puback{
          packet_id: packet_id,
          status: {:accepted, :ok}
        }
      }

  def decode(<<4::4, 0::4>>, <<packet_id::16, reason_code::8, property_length::8, _rest::binary>>)
      when packet_id in 0x0001..0xFFFF and
             (reason_code == 0x00 or
                reason_code == 0x10 or
                reason_code == 0x80 or
                reason_code == 0x83 or
                reason_code == 0x87 or
                reason_code == 0x90 or
                reason_code == 0x91 or
                reason_code == 0x97 or
                reason_code == 0x99),
      do: {
        :puback,
        %Packet.Puback{
          packet_id: packet_id,
          status: decode_reason_code(reason_code)
        }
      }

  def decode(<<4::4, 0::4>>, <<_packet_id::16, reason_code::8, _rest::binary>>) do
    {:puback_error, "unknown reason_code. reason_code=#{reason_code}"}
  end

  @spec decode_reason_code(<<_::8>>) :: status()
  def decode_reason_code(reason_code) do
    case reason_code do
      0x00 -> {:accepted, :ok}
      0x10 -> {:accepted, :no_matching_subscribers}
      0x80 -> {:refused, :unspecified_error}
      0x83 -> {:refused, :implementation_specific_error}
      0x87 -> {:refused, :not_authorized}
      0x90 -> {:refused, :topic_name_invalid}
      0x91 -> {:refused, :packet_identifier_in_use}
      0x97 -> {:refused, :quota_exceeded}
      0x99 -> {:refused, :payload_format_invalid}
    end
  end

  defimpl Packet.Encodable do
    def encode(%Packet.Puback{packet_id: packet_id, status: status})
        when packet_id in 0x0001..0xFFFF and status == nil do
      packet_length = 2

      <<4::4, 0::4>> <>
        <<packet_length::8>> <>
        <<packet_id::16>>
    end

    def encode(%Packet.Puback{packet_id: packet_id, status: status})
        when packet_id in 0x0001..0xFFFF and status != nil do
      packet_length = 4
      properties_length = 0

      <<4::4, 0::4>> <>
        <<packet_length::8>> <>
        <<packet_id::16>> <>
        <<to_return_code(status)::8>> <>
        <<properties_length>>
    end

    defp to_return_code({:accepted, reason}) do
      case reason do
        :ok -> 0x00
        :no_matching_subscribers -> 0x10
      end
    end

    defp to_return_code({:refused, reason}) do
      case reason do
        :unspecified_error -> 0x80
        :implementation_specific_error -> 0x83
        :not_authorized -> 0x87
        :topic_name_invalid -> 0x90
        :packet_identifier_in_use -> 0x91
        :quota_exceeded -> 0x97
        :payload_format_invalid -> 0x99
      end
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
