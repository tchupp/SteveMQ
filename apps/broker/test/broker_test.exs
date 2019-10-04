defmodule BrokerTest do
  use ExUnit.Case

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
  end

  setup do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)
    %{socket: socket}
  end

  test "SUBSCRIBE flow", %{socket: socket} do
    connect =
      <<16, 24, 0, 4, ?M, ?Q, ?T, ?T, 5, 2, 0, 60, 0, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r,
        ?l, ?d>>

    packet_id = 65
    subscribe = <<130, 14, packet_id::16, 0, 0, 9, ?t, ?e, ?s, ?t, ?T, ?o, ?p, ?i, ?c, 0>>

    assert send_and_recv(socket, connect) == <<32, 3, 0, 0, 0>>
    <<144, _::binary>> = send_and_recv(socket, subscribe)
  end

  test "CONNACKs with error code when bad CONNECT is sent", %{socket: socket} do
    bad_header_flags = 4
    connect = <<1::4, bad_header_flags::4, 0, 0, 0>>

    <<32, 3, 0, 0, reason_code>> = send_and_recv(socket, connect)
    assert reason_code != 0
  end

  defp send_and_recv(socket, packet) do
    :ok = :gen_tcp.send(socket, packet)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end
