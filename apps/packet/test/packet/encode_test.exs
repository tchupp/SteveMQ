defmodule Packet.EncodeTest do
  use ExUnit.Case

  test "encodes CONNECT with client id and clean" do
    assert Packet.Encode.connect("samuel-l-jackson", false) ==
             <<16, 29>> <> # fixed header
             <<0, 4, "MQTT">> <> # protocol
             <<5>> <> # protocol level
             <<0>> <> # connect flags
             <<0, 60>> <> # keep alive
             <<0>> <> # property length
             <<0, 16, "samuel-l-jackson">> # payload: client id

  end

  test "sets clean start flag when encoding CONNECT" do
    clean_start_connect = Packet.Encode.connect("brian-boitano", true)
    dirty_start_connect = Packet.Encode.connect("kristi-yamaguchi", false)

    assert :binary.at(dirty_start_connect, 12) == 0
    assert :binary.at(clean_start_connect, 12) == 2
  end

  test "encodes a basic CONNACK packet" do
    assert Packet.Encode.connack(session_present?: false) == <<32, 3, 0, 0, 0>>
    assert Packet.Encode.connack(session_present?: true) == <<32, 3, 1, 0, 0>>
  end

  test "encodes CONNACK with error codes" do
    assert Packet.Encode.connack(:error) == <<32, 3, 0, 0, 131>>
  end

  test "encodes PUBACK with packet id" do
    packet_id = 123

    assert Packet.Encode.puback(packet_id) == <<64, 4, packet_id::16, 0, 0>>
  end

  test "encodes SUBSCRIBE" do
    assert Packet.Encode.subscribe(47, "a/topic") ==
             <<8::4, 2::4>> <> <<12>> <> # fixed header
             <<0, 47>> <> # packet id
             <<0>> <> # properties length
             <<0, 7, "a/topic">> #payload
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
