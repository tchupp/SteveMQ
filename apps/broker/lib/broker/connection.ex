defmodule Broker.Connection do
  use GenServer, restart: :temporary
  require Logger

  # client

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def process_incoming(server, packet) do
    GenServer.call(server, {:process_incoming, packet})
  end

  def publish_outgoing(server, packet) do
    GenServer.call(server, {:publish_outgoing, packet})
  end

  # server

  @impl true
  def init(socket) do
    server = self()
    Task.start_link(fn -> read_loop(server, socket) end)
    {:ok, {socket, :none}}
  end

  defp read_loop(server, socket) do
    result = :gen_tcp.recv(socket, 0)

    case result do
      {:ok, raw_packet} ->
        :ok = process_incoming(server, raw_packet)
        read_loop(server, socket)

      {:error, :closed} ->
        Logger.info("connection closed. shutting down process")
        exit(:shutdown)
    end
  end

  @impl true
  def handle_call({:process_incoming, raw_packet}, _from, {socket, client_id}) do
    parsed_packet = Packet.Decode.parse(raw_packet)
    handle({socket, client_id}, parsed_packet)
  end

  @impl true
  def handle_call(
        {:publish_outgoing, {:publish, %{topic: topic, message: message}}},
        _from,
        {socket, client_id}
      ) do
    Logger.info("Publishing to client with msg: #{message}")

    :gen_tcp.send(socket, Packet.Encode.publish(topic, message))
    {:reply, :ok, {socket, client_id}}
  end

  defp handle({socket, :none}, {:connect, %{client_id: client_id}}) do
    Broker.Connection.Registry.register(Broker.Connection.Registry, client_id, self())
    Logger.info("received CONNECT from client id: #{client_id}. Sending CONNACK")

    :gen_tcp.send(socket, Packet.Encode.connack())
    {:reply, :ok, {socket, {:some, client_id}}}
  end

  defp handle(
         {socket, {:some, client_id}},
         {:subscribe, %{topic_filter: topic_filter, packet_id: packet_id}}
       ) do
    Logger.info("received SUBSCRIBE to #{topic_filter}, sending SUBACK")

    Broker.SubscriptionRegistry.add_subscription(
      Broker.SubscriptionRegistry,
      client_id,
      topic_filter
    )

    :gen_tcp.send(socket, Packet.Encode.suback(packet_id))
    {:reply, :ok, {socket, {:some, client_id}}}
  end

  defp handle({socket, {:some, client_id}}, {:publish, %{topic: topic, message: message}}) do
    Logger.info("received PUBLISH to #{topic} from client: #{client_id}")

    subscribers = Broker.SubscriptionRegistry.get_subscribers(Broker.SubscriptionRegistry, topic)

    for subscriber <- subscribers do
      pid = Broker.Connection.Registry.get_pid(Broker.Connection.Registry, subscriber)
      Broker.Connection.publish_outgoing(pid, {:publish, %{topic: topic, message: message}})
    end

    {:reply, :ok, {socket, {:some, client_id}}}
  end

  defp handle({socket, {:some, client_id}}, {:disconnect}) do
    Logger.info("received DISCONNECT from client id: #{client_id}")

    {:reply, :ok, {socket, {:some, client_id}}}
  end

  defp handle({socket, _client_id}, {:error, error}) do
    Logger.info("error reading tcp socket: #{error}")

    :gen_tcp.send(socket, Packet.Encode.connack(:error))
    exit(error)
  end
end
