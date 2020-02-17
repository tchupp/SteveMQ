defmodule Packet.EncodeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  describe "CONNECT" do
    property "encodes CONNECT" do
      protocol_level = 5

      check all clean_start <- StreamData.boolean(),
                keep_alive <- StreamData.integer(0..65535),
                client_id <- StreamData.string(:alphanumeric, min_length: 1),
                username <- StreamData.string(:alphanumeric, min_length: 1),
                password <- StreamData.string(:alphanumeric, min_length: 1),
                will_present <- StreamData.boolean(),
                will_retain <- StreamData.boolean(),
                will_qos <- StreamData.member_of(0..2),
                will_topic <- StreamData.string(:alphanumeric, min_length: 1),
                will_message <- StreamData.string(:alphanumeric, min_length: 1),
                session_expiry <- StreamData.integer(0..2_147_483_647),
                receive_maximum <- StreamData.integer(1..65_535) do
        connect = %Packet.Connect{
          clean_start: clean_start,
          client_id: client_id,
          username: username,
          password: password,
          protocol_level: protocol_level,
          keep_alive: keep_alive,
          will:
            if(!will_present,
              do: nil,
              else: %Packet.Publish{
                retain: will_retain,
                topic: will_topic,
                qos: will_qos,
                message: will_message
              }
            ),
          session_expiry: session_expiry,
          receive_maximum: receive_maximum
        }

        assert {:connect, connect} ==
                 connect
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "CONNACK" do
    property "encodes CONNACK" do
      check all session_present? <- StreamData.boolean(),
                status <-
                  StreamData.member_of([
                    :accepted,
                    {:refused, :unacceptable_protocol_version},
                    {:refused, :identifier_rejected},
                    {:refused, :server_unavailable},
                    {:refused, :bad_user_name_or_password},
                    {:refused, :not_authorized}
                  ]) do
        connack = %Packet.Connack{
          session_present?: session_present?,
          status: status
        }

        assert {:connack, connack} ==
                 connack
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "PUBACK" do
    property "encodes PUBACK - short form" do
      check all packet_id <- StreamData.positive_integer() do
        initial = %Packet.Puback{
          packet_id: packet_id,
          status: nil
        }

        expected = %Packet.Puback{
          packet_id: packet_id,
          status: {:accepted, :ok}
        }

        assert {:puback, expected} ==
                 initial
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end

    property "encodes PUBACK - long form" do
      check all packet_id <- StreamData.positive_integer(),
                status <-
                  StreamData.member_of([
                    {:accepted, :ok},
                    {:accepted, :no_matching_subscribers},
                    {:refused, :unspecified_error},
                    {:refused, :implementation_specific_error},
                    {:refused, :not_authorized},
                    {:refused, :topic_name_invalid},
                    {:refused, :packet_identifier_in_use},
                    {:refused, :quota_exceeded},
                    {:refused, :payload_format_invalid}
                  ]) do
        connack = %Packet.Puback{
          packet_id: packet_id,
          status: status
        }

        assert {:puback, connack} ==
                 connack
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "PUBLISH" do
    property "encodes PUBLISH - qos 0" do
      check all message <- StreamData.string(:alphanumeric, min_length: 0),
                topic <- StreamData.string(:alphanumeric, min_length: 1),
                retain <- StreamData.boolean() do
        qos_code = 0

        publish = %Packet.Publish{
          topic: topic,
          message: message,
          qos: qos_code,
          retain: retain
        }

        assert {:publish_qos0, publish} ==
                 publish
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end

    property "encodes PUBLISH - qos 1/2" do
      publish_qos = [
        {1, :publish_qos1},
        {2, :publish_qos2}
      ]

      check all message <- StreamData.string(:alphanumeric, min_length: 0),
                topic <- StreamData.string(:alphanumeric, min_length: 1),
                dup <- StreamData.boolean(),
                retain <- StreamData.boolean(),
                packet_id <- StreamData.positive_integer(),
                {qos_code, qos_key} <- StreamData.member_of(publish_qos) do
        publish = %Packet.Publish{
          topic: topic,
          message: message,
          qos: qos_code,
          retain: retain,
          packet_id: packet_id,
          dup: dup
        }

        assert {qos_key, publish} ==
                 publish
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "SUBSCRIBE" do
    property "encodes SUBSCRIBE" do
      check all packet_id <- StreamData.positive_integer(),
                topics <-
                  {StreamData.binary(), StreamData.member_of(0..2)}
                  |> StreamData.tuple()
                  |> StreamData.list_of(min_length: 1) do
        subscribe = %Packet.Subscribe{
          topics: topics,
          packet_id: packet_id
        }

        assert {:subscribe, subscribe} ==
                 subscribe
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "SUBACK" do
    property "encodes SUBACK - zero acks" do
      check all packet_id <- StreamData.positive_integer() do
        initial = %Packet.Suback{
          packet_id: packet_id
        }

        expected = %Packet.Suback{
          packet_id: packet_id,
          acks: []
        }

        assert {:suback, expected} ==
                 initial
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end

    property "encodes SUBACK - many acks" do
      qos_possibilities = [
        0x00,
        0x01,
        0x02,
        0x80
      ]

      check all packet_id <- StreamData.positive_integer(),
                acks <-
                  StreamData.member_of(qos_possibilities)
                  |> StreamData.list_of() do
        initial = %Packet.Suback{
          packet_id: packet_id,
          acks: acks |> Enum.map(&suback_ack_to_tuple(&1))
        }

        expected = %Packet.Suback{
          packet_id: packet_id,
          acks: acks |> Enum.map(&suback_ack_to_tuple(&1))
        }

        assert {:suback, expected} ==
                 initial
                 |> Packet.encode()
                 |> Packet.decode()
      end
    end
  end

  describe "PINGREQ" do
    test "encodes PINGREQ" do
      pingreq = %Packet.Pingreq{}

      assert {:pingreq, pingreq} ==
               pingreq
               |> Packet.encode()
               |> Packet.decode()
    end
  end

  describe "PINGRESP" do
    test "encodes PINGRESP" do
      pingresp = %Packet.Pingresp{}

      assert {:pingresp, pingresp} ==
               pingresp
               |> Packet.encode()
               |> Packet.decode()
    end
  end

  test "encodes handle utf8 string > 255 chars" do
    big_string =
      "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890" <>
        "123456789012345678901234567890"

    assert Packet.Encode2.fixed_length_prefixed(big_string) == <<1, 44>> <> big_string
  end

  describe "variable_length_prefixed" do
    property "encodes data with variable length prefix - one byte" do
      check all bytes <- StreamData.binary(min_length: 0, max_length: 127) do
        assert {byte_size(bytes), 1, bytes} ==
                 bytes
                 |> Packet.Encode2.variable_length_prefixed()
                 |> Packet.Decode.variable_length_prefixed()
      end
    end

    property "encodes data with variable length prefix - two byte" do
      check all bytes <- StreamData.binary(min_length: 128, max_length: 16_383) do
        assert {byte_size(bytes), 2, bytes} ==
                 bytes
                 |> Packet.Encode2.variable_length_prefixed()
                 |> Packet.Decode.variable_length_prefixed()
      end
    end

    property "encodes data with variable length prefix - three byte" do
      check all bytes <- StreamData.binary(min_length: 16_384, max_length: 2_097_151) do
        assert {byte_size(bytes), 3, bytes} ==
                 bytes
                 |> Packet.Encode2.variable_length_prefixed()
                 |> Packet.Decode.variable_length_prefixed()
      end
    end

    #    This test takes more than 60 seconds to run, probably not needed
    @tag skip: true
    property "encodes data with variable length prefix - four byte" do
      check all bytes <-
                  StreamData.binary(min_length: 2_097_152, max_length: 268_435_455) do
        assert {byte_size(bytes), 4, bytes} ==
                 bytes
                 |> Packet.Encode2.variable_length_prefixed()
                 |> Packet.Decode.variable_length_prefixed()
      end
    end
  end

  defp suback_ack_to_tuple(0x80), do: {:error, :access_denied}
  defp suback_ack_to_tuple(ack) when ack in 0x00..0x02, do: {:ok, ack}
end
