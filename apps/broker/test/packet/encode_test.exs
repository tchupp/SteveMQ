defmodule Packet.EncodeTest do
  use ExUnit.Case

  test "encodes a basic CONNACK packet" do
    assert Packet.Encode.connack() == <<32, 3, 0, 0, 0>>
  end

  test "encodes CONNACK with error codes" do
    assert Packet.Encode.connack(:error) == <<32, 3, 0, 0, 131>>
  end

  test "encodes PUBACK with packet id" do
    packet_id = 123

    assert Packet.Encode.puback(packet_id) == <<64, 4, packet_id::16, 0, 0>>
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
