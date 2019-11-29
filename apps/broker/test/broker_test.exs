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
    connect = <<16, 24, 0, 4, "MQTT", 5, 2, 0, 60, 0, 0, 11, "hello", 32, "world">>

    {:connack, packet} = send_and_recv(socket, connect)

    assert packet == %Packet.Connack{
             session_present?: false,
             status: :accepted
           }

    subscribe_packet_id = 65

    encoded_subscribe =
      Packet.encode(%Packet.Subscribe{
        packet_id: subscribe_packet_id,
        topics: [
          {"testTopic1", 0},
          {"testTopic2", 1}
        ]
      })

    {:suback, packet} = send_and_recv(socket, encoded_subscribe)

    assert packet == %Packet.Suback{
             packet_id: subscribe_packet_id,
             acks: [
               {:ok, 0},
               {:ok, 1}
             ]
           }
  end

  test "PINGREQ flow", %{socket: socket} do
    connect = <<16, 24, 0, 4, "MQTT", 5, 2, 0, 60, 0, 0, 11, "hello", 32, "world">>

    {:connack, packet} = send_and_recv(socket, connect)

    assert packet == %Packet.Connack{
             session_present?: false,
             status: :accepted
           }

    encoded_pingreq = Packet.encode(%Packet.Pingreq{})

    {:pingresp, packet} = send_and_recv(socket, encoded_pingreq)

    assert packet == %Packet.Pingresp{}
  end

  test "CONNACKs with error code when bad CONNECT is sent", %{socket: socket} do
    bad_header_flags = 4
    connect = <<1::4, bad_header_flags::4, 0, 0, 0>>

    assert send_and_recv(socket, connect) == {:error, :closed}
  end

  defp send_and_recv(socket, packet) do
    :ok = :gen_tcp.send(socket, packet)

    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, packet} -> Packet.decode(packet)
      {:error, error} -> {:error, error}
    end
  end
end
