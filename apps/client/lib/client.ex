defmodule Client do
  def subscribe_1msg(client_id, topic_filter) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    IO.puts("got the tcp going")

    connect(socket, client_id)
    subscribe(socket, topic_filter, 0)

    {:ok, packet} = :gen_tcp.recv(socket, 0, 2000)
    {:publish_qos0, data} = Packet.decode(packet)
    data[:message]
  end

  def publish(client_id, message, topic) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)
    connect(socket, client_id)

    :ok = :gen_tcp.send(socket, Packet.Encode.publish(topic, message))
  end

  defp connect(socket, client_id) do
    :ok = :gen_tcp.send(socket, Packet.Encode.connect(client_id, true))
    IO.puts("sent a connect")
    {:ok, <<32, 3, 0, 0, 0>>} = :gen_tcp.recv(socket, 0, 1000)
    IO.puts("got a thing")
  end

  defp subscribe(socket, topic_filter, qos) do
    :ok = :gen_tcp.send(socket, Packet.Encode.subscribe(123, topic_filter))
    {:ok, suback} = :gen_tcp.recv(socket, 0, 1000)
    {:suback, _} = Packet.decode(suback)
  end
end
