defmodule Client do
  def subscribe_1msg(client_id, topic_filter, qos \\ 0) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    :ok = connect(socket, client_id, false)
    :ok = subscribe(socket, topic_filter, qos)

    {:ok, packet} = :gen_tcp.recv(socket, 0, 2000)
    {:publish_qos0, %Packet.Publish{message: message}} = Packet.decode(packet)
    message
  end

  def publish(client_id, message, topic, qos) when qos == 0 do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)
    :ok = connect(socket, client_id, false)

    :ok =
      :gen_tcp.send(
        socket,
        Packet.encode(%Packet.Publish{
          topic: topic,
          message: message,
          qos: qos,
          retain: false
        })
      )

    :ok
  end

  def publish(client_id, message, topic, qos) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)
    :ok = connect(socket, client_id, false)

    :ok =
      :gen_tcp.send(
        socket,
        Packet.encode(%Packet.Publish{
          packet_id: 1,
          topic: topic,
          message: message,
          qos: qos,
          retain: false
        })
      )

    {:ok, puback} = :gen_tcp.recv(socket, 0, 1000)
    {:puback, %Packet.Puback{packet_id: 1, status: {:accepted, :ok}}} = Packet.decode(puback)

    :ok
  end

  def connect(socket, client_id, clean_start) do
    :ok = :gen_tcp.send(socket, Packet.Encode.connect(client_id, clean_start))
    {:ok, <<32, 3, 0, 0, 0>>} = :gen_tcp.recv(socket, 0, 1000)

    :ok
  end

  defp subscribe(socket, topic_filter, qos) do
    encoded_subscribe =
      Packet.encode(%Packet.Subscribe{packet_id: 123, topics: [{topic_filter, qos}]})

    :ok = :gen_tcp.send(socket, encoded_subscribe)
    {:ok, suback} = :gen_tcp.recv(socket, 0, 1000)
    {:suback, %Packet.Suback{packet_id: 123, acks: [{:ok, 0}]}} = Packet.decode(suback)

    :ok
  end
end
