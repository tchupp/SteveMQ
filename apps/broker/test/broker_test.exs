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
    connect = <<12>>
    connack = <<32, 2, 0, 0>>

    assert send_and_recv(socket, connect) == connack
  end

  defp send_and_recv(socket, packet) do
    :ok = :gen_tcp.send(socket, packet)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end
