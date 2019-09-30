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

  test "CONNECT returns a CONNACK", %{socket: socket} do
    connect =
      <<16, 23, 0, 4, ?M, ?Q, ?T, ?T, ?4, 2, 0, 60, 0, 11, ?h, ?e, ?l, ?l, ?o, 32, ?w, ?o, ?r, ?l,
        ?d>>

    assert send_and_recv(socket, connect) == <<32, 2, 0, 0>>
  end

  test "CONNACKs with error code when bad CONNECT is sent", %{socket: socket} do
    wrong_remaining_length = <<16, 0, 0, 0>>

    <<32, 2, 0, reason_code>> = send_and_recv(socket, wrong_remaining_length)
    assert reason_code != 0
  end

  defp send_and_recv(socket, packet) do
    :ok = :gen_tcp.send(socket, packet)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end
