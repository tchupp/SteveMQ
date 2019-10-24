defmodule Client do

  def subscribe_1msg(client_id, topic_filter, qos) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    connect(socket, client_id)
    subscribe(socket, topic_filter, qos)
  end

  def publish(client_id, topic, qos) do

  end

  defp connect(socket, client_id) do
    :ok = :gen_tcp.send(socket, Packet.Encode.connect(client_id, true))
    {:ok, <<32, 3, 0, 0, 0>>} = :gen_tcp.recv(socket, 0, 1000)
  end

  defp subscribe(socket, topic_filter, qos) do
  end

end
