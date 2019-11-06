defmodule Packet.EncodeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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
        actual = %Packet.Puback{
          packet_id: packet_id,
          status: nil
        }

        expected = %Packet.Puback{
          packet_id: packet_id,
          status: {:accepted, :ok}
        }

        assert {:puback, expected} ==
                 actual
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

  test "encodes CONNECT with client id and clean" do
    # fixed header
    # protocol
    # protocol level
    # connect flags
    # keep alive
    # property length
    # payload: client id
    assert Packet.Encode.connect("samuel-l-jackson", false) ==
             <<16, 29>> <>
               <<0, 4, "MQTT">> <>
               <<5>> <>
               <<0>> <>
               <<0, 60>> <>
               <<0>> <>
               <<0, 16, "samuel-l-jackson">>
  end

  test "sets clean start flag when encoding CONNECT" do
    clean_start_connect = Packet.Encode.connect("brian-boitano", true)
    dirty_start_connect = Packet.Encode.connect("kristi-yamaguchi", false)

    assert :binary.at(dirty_start_connect, 9) == 0
    assert :binary.at(clean_start_connect, 9) == 2
  end

  test "encodes SUBSCRIBE" do
    # fixed header
    # packet id
    # properties length
    # payload
    assert Packet.Encode.subscribe(47, "a/topic") ==
             <<8::4, 2::4>> <>
               <<12>> <>
               <<0, 47>> <>
               <<0>> <>
               <<0, 7, "a/topic">>
  end

  test "encodes SUBACK" do
    packet_id = 45
    suback = Packet.Encode.suback(packet_id)

    assert suback == <<144, 3, packet_id::16, 0>>
  end

  test "encodes PUBLISH" do
    publish = Packet.Encode.publish("a/topic", "hi")
    assert publish == <<3::4, 0::4, 12, 0, 7, ?a, ?/, ?t, ?o, ?p, ?i, ?c, 0, ?h, ?i>>
  end

  test "encodes a PINGRES" do
    assert Packet.Encode.pingresp() == <<13::4, 0::4, 0>>
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

    assert Packet.Encode.utf8(big_string) == <<1, 44>> <> big_string
  end
end
