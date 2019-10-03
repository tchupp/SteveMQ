defmodule Broker.PacketTest do
  use ExUnit.Case

  test "returns error for unrecognized message types" do
    {result, _} = Broker.Packet.parse(<<0, 2, 0, 0>>)
    assert result == :error
  end

  test "parses CONNECT" do
    connect =
      <<16, 24, 0, 4, ?M, ?Q, ?T, ?T, 5, 2, 0, 60, 0, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r,
        ?l, ?d>>

    {result, data} = Broker.Packet.parse(connect)

    assert result == :connect
    assert data[:client_id] == "hello world"
    assert data[:connect_flags] == 2
    assert data[:keep_alive] == 60
    assert data[:protocol_level] == 5
  end

  test "parses SUBSCRIBE" do
    packet_id = 123
    subscribe = <<130, 14, packet_id::16, 0, 0, 9, ?t, ?e, ?s, ?t, ?T, ?o, ?p, ?i, ?c, 0>>
    {result, packet} = Broker.Packet.parse(subscribe)

    assert result == :subscribe
    assert packet[:topic_filter] == "testTopic"
    assert packet[:packet_id] == packet_id
  end

  test "parses PUBLISH" do
    publish = <<3::4, 0::4, 14, 0, 5, ?t, ?o, ?p, ?i, ?c, ?m, ?e, ?s, ?s, ?a, ?g, ?e>>

    {_, packet} = Broker.Packet.parse(publish)

    assert packet[:topic] == "topic"
    assert packet[:message] == "message"
  end

  test "can parse one length variable length ints" do
    assert Broker.Packet.parse_variable_int(<<0, 0>>) == {0, <<0>>}
    assert Broker.Packet.parse_variable_int(<<127, 0>>) == {127, <<0>>}
  end

  test "can parse two length variable length ints" do
    assert Broker.Packet.parse_variable_int(<<128, 1, 0>>) == {128, <<0>>}
    assert Broker.Packet.parse_variable_int(<<255, 127, 0>>) == {16_383, <<0>>}
  end

  test "can parse three length variable length ints" do
    assert Broker.Packet.parse_variable_int(<<128, 128, 1, 0>>) == {16_384, <<0>>}
    assert Broker.Packet.parse_variable_int(<<255, 255, 127, 0>>) == {2_097_151, <<0>>}
  end

  test "can parse four length variable length ints" do
    assert Broker.Packet.parse_variable_int(<<128, 128, 128, 1, 0>>) == {2_097_152, <<0>>}
    assert Broker.Packet.parse_variable_int(<<255, 255, 255, 127, 0>>) == {268_435_455, <<0>>}
  end

  test "max variable length bytes is 4" do
    assert_raise RuntimeError, ~r/error/, fn ->
      Broker.Packet.parse_variable_int(<<255, 255, 255, 255, 7>>)
    end
  end

end
