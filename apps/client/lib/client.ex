defmodule Client do
  def subscribe_1msg(client_id, topic_filter, qos \\ 0) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    connect(socket, client_id)
    subscribe(socket, topic_filter, qos)

    {:ok, packet} = :gen_tcp.recv(socket, 0, 2000)
    {:publish_qos0, %Packet.Publish{message: message}} = Packet.decode(packet)
    message
  end

  def publish(client_id, message, topic) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)
    connect(socket, client_id)

    :ok =
      :gen_tcp.send(
        socket,
        Packet.encode(%Packet.Publish{topic: topic, message: message, qos: 0, retain: false})
      )
  end

  defp connect(socket, client_id) do
    :ok = :gen_tcp.send(socket, Packet.Encode.connect(client_id, true))
    {:ok, <<32, 3, 0, 0, 0>>} = :gen_tcp.recv(socket, 0, 1000)
  end

  defp subscribe(socket, topic_filter, qos) do
    :ok = :gen_tcp.send(socket, Packet.Encode.subscribe(123, topic_filter))
    {:ok, suback} = :gen_tcp.recv(socket, 0, 1000)
    {:suback, _} = Packet.decode(suback)
  end
end
