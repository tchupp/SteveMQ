defmodule Client do
  use GenServer
  require Logger

  defstruct client_id: nil, socket: nil, inbox: []

  # client

  def start_link(%ClientOptions{} = opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def receive_packet(server, packet) do
    GenServer.call(server, {:receive_packet, packet})
  end

  def get_messages(server) do
    GenServer.call(server, :get_messages)
  end

  def subscribe(server, topic_filter, qos \\ 0) do
    GenServer.call(server, {:subscribe, topic_filter, qos})
  end

  def publish(server, message, topic, qos \\ 0) do
    GenServer.call(server, {:publish, message, topic, qos})
  end

  # server

  @impl true
  def init(%ClientOptions{} = opts) do
    socket = connect(opts)
    server = self()

    Task.start_link(fn -> read_loop(server, socket) end)

    {:ok, %Client{client_id: opts.client_id, socket: socket}}
  end

  defp connect(%ClientOptions{} = opts) do
    {:ok, socket} = :gen_tcp.connect(opts.host, opts.port, [:binary, active: false])

    :ok = :gen_tcp.send(socket, Packet.Encode.connect(opts.client_id, opts.clean_start))
    {:ok, <<32, 3, 0, 0, 0>>} = :gen_tcp.recv(socket, 0, 1000)

    socket
  end

  defp read_loop(server, socket) do
    result = :gen_tcp.recv(socket, 0)

    case result do
      {:ok, raw_packet} ->
        packet = Packet.decode(raw_packet)
        :ok = receive_packet(server, packet)
        read_loop(server, socket)

      {:error, :closed} ->
        Logger.info("client tcp socket closed")
    end
  end

  @impl true
  def handle_call({:receive_packet, packet}, _from, state) do
    case packet do
      {:publish_qos0, _} ->
        {:reply, :ok, put_in(state.inbox, state.inbox ++ [packet])}

      {:publish_qos1, _} ->
        {:reply, :ok, put_in(state.inbox, state.inbox ++ [packet])}

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, state.inbox, state}
  end

  @impl true
  def handle_call({:subscribe, topic_filter, qos}, _from, state) do
    encoded_subscribe =
      Packet.encode(%Packet.Subscribe{packet_id: 123, topics: [{topic_filter, qos}]})

    :ok = :gen_tcp.send(state.socket, encoded_subscribe)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:publish, message, topic, qos}, _from, state) when qos == 0 do
    encoded_publish =
      Packet.encode(%Packet.Publish{
        topic: topic,
        message: message,
        qos: qos,
        retain: false
      })

    :ok = :gen_tcp.send(state.socket, encoded_publish)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:publish, message, topic, qos}, _from, state) do
    encoded_publish =
      Packet.encode(%Packet.Publish{
        packet_id: 1,
        topic: topic,
        message: message,
        qos: qos,
        retain: false
      })

    :ok = :gen_tcp.send(state.socket, encoded_publish)
    {:reply, :ok, state}
  end
end
