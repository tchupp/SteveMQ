defmodule Packet.DecodeTest do
  use ExUnit.Case, async: true

  describe "CONNECT" do
    test "parses CONNECT" do
      connect =
        <<16, 24, 0, 4, ?M, ?Q, ?T, ?T, 5, 2, 0, 60, 0, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r,
          ?l, ?d>>

      {type, data} = Packet.Decode.decode(connect)

      assert type == :connect
      assert data[:client_id] == "hello world"
      assert data[:connect_flags] == 2
      assert data[:keep_alive] == 60
      assert data[:protocol_level] == 5
    end
  end

  describe "CONNACK" do
  end

  describe "PUBLISH" do
    test "parses PUBLISH" do
      publish =
        <<3::4, 0::4>> <>
          <<15>> <>
          <<0, 5, ?t, ?o, ?p, ?i, ?c>> <>
          <<0>> <>
          <<?m, ?e, ?s, ?s, ?a, ?g, ?e>>

      {type, packet} = Packet.Decode.decode(publish)

      assert type == :publish
      assert packet[:topic] == "topic"
      assert packet[:message] == "message"
    end

    test "parses PUBLISH with extra chars" do
      publish =
        <<3::4, 0::4>> <>
          <<15>> <>
          <<0, 5, ?t, ?o, ?p, ?i, ?c>> <>
          <<0>> <>
          <<?m, ?e, ?s, ?s, ?a, ?g, ?e, ??, ?!>>

      {type, packet} = Packet.Decode.decode(publish)

      assert type == :publish
      assert packet[:topic] == "topic"
      assert packet[:message] == "message"
    end
  end

  describe "PUBACK" do
  end

  describe "PUBREC" do
  end

  describe "PUBREL" do
  end

  describe "PUBCOMP" do
  end

  describe "SUBSCRIBE" do
    test "parses SUBSCRIBE" do
      packet_id = 123

      subscribe =
        <<8::4, 2::4>> <>
          <<14, packet_id::16, 0, 0, 9>> <>
          <<?t, ?e, ?s, ?t, ?T, ?o, ?p, ?i, ?c, 0>>

      {type, packet} = Packet.Decode.decode(subscribe)

      assert type == :subscribe
      assert packet[:topic_filter] == "testTopic"
      assert packet[:packet_id] == packet_id
    end
  end

  describe "SUBACK" do
  end

  describe "UNSUBSCRIBE" do
  end

  describe "UNSUBACK" do
  end

  describe "PINGREQ" do
  end

  describe "PINGRES" do
  end

  describe "DISCONNECT" do
  end

  describe "ERROR" do
    test "returns error for unrecognized message types" do
      {type, _} = Packet.Decode.decode(<<0, 2, 0, 0>>)
      assert type == :unknown
    end
  end

  test "can parse one length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<0, 0>>) == {0, 1, <<0>>}
    assert Packet.Decode.parse_variable_int(<<127, 0>>) == {127, 1, <<0>>}
  end

  test "can parse two length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 1, 0>>) == {128, 2, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 127, 0>>) == {16_383, 2, <<0>>}
  end

  test "can parse three length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 128, 1, 0>>) == {16_384, 3, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 255, 127, 0>>) == {2_097_151, 3, <<0>>}
  end

  test "can parse four length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 128, 128, 1, 0>>) == {2_097_152, 4, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 255, 255, 127, 0>>) == {268_435_455, 4, <<0>>}
  end

  test "max variable length bytes is 4" do
    assert_raise RuntimeError, ~r/error/, fn ->
      Packet.Decode.parse_variable_int(<<255, 255, 255, 255, 7>>)
    end
  end
end
