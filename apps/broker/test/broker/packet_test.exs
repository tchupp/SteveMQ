defmodule Broker.PacketTest do
  use ExUnit.Case

  test "returns error for unrecognized message types" do
    {result, _} = Broker.Packet.parse(<<0, 2, 0, 0>>)
    assert result == :error
  end

  test "parses CONNECT" do
    connect = <<16, 23, 0, 4, ?M, ?Q, ?T, ?T, 4, 2, 0, 60, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r, ?l, ?d>>
    {result, data} = Broker.Packet.parse(connect)

    assert result == :connect
    assert data[:client_id] == "hello world"
    assert data[:connect_flags] == 2
    assert data[:keep_alive] == 60
  end

  test "returns error when cant parse CONNECT" do
    connect_with_bad_protocol = <<16, 23, 0, 4, ?H, ?T, ?T, ?P, 4, 2, 0, 60, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r, ?l, ?d>>

    {result, msg} = Broker.Packet.parse(connect_with_bad_protocol)
    assert result == :error
    assert msg == "could not parse CONNECT"
  end
end
