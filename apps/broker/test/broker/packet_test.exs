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
    subscribe = <<130, 14, 0, 0, 0, 9, ?t, ?e, ?s, ?t, ?T, ?o, ?p, ?i, ?c, 0>>
    {result, packet} = Broker.Packet.parse(subscribe)

    assert result == :subscribe
    assert packet[:topic] == "testTopic"
  end

  test "parses PUBLISH" do
    publish = <<3::4, 0::4, 14, 0, 5, ?t, ?o, ?p, ?i, ?c, ?m, ?e, ?s, ?s, ?a, ?g, ?e>>

    {_, packet} = Broker.Packet.parse(publish)

    assert packet[:topic] == "topic"
    assert packet[:message] == "message"
  end
end
