defmodule Client do
  use GenServer
  require Logger

  @opaque t :: %__MODULE__{
            client_id: String.t(),
            opts: ClientOptions.t()
          }

  defstruct client_id: nil, opts: nil, socket: nil, inbox: []

  alias __MODULE__, as: State

  # client

  def start_link(%ClientOptions{client_id: client_id} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via_name(client_id))
  end

  def connect(name, client_id: client_id, clean_start: clean_start) when is_atom(client_id) do
    connect(name, client_id: Atom.to_string(client_id), clean_start: clean_start)
  end

  def connect(name, client_id: client_id, clean_start: clean_start) do
    GenServer.call(via_name(name), {:connect, client_id: client_id, clean_start: clean_start})
  end

  def receive_packet(name, packet) do
    GenServer.call(via_name(name), {:receive_packet, packet})
  end

  def get_messages(name) do
    GenServer.call(via_name(name), :get_messages)
  end

  def subscribe(name, topic_filter: topic_filter, qos: qos) do
    GenServer.call(via_name(name), {:subscribe, topic_filter: topic_filter, qos: qos})
  end

  def publish(name, topic, message, qos \\ 0) do
    GenServer.call(via_name(name), {:publish, message, topic, qos})
  end

  def stop(name) do
    GenServer.stop(via_name(name))
  end

  defp via_name(client_id) do
    Client.Bucket.via_name(__MODULE__, client_id)
  end

  # server

  @impl true
  def init(%ClientOptions{client_id: client_id} = opts) do
    {:ok, %State{client_id: client_id, opts: opts}}
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
  def handle_call(
        {:connect, client_id: client_id, clean_start: clean_start},
        _from,
        %Client{opts: opts} = state
      ) do
    with {:ok, socket} = :gen_tcp.connect(opts.host, opts.port, [:binary, active: false]),
         :ok = :gen_tcp.send(socket, Packet.Encode.connect(client_id, clean_start)),
         {:ok, raw_packet} <- :gen_tcp.recv(socket, 0, 5000) do
      case Packet.decode(raw_packet) do
        {:connack, %Packet.Connack{session_present?: session_present?, status: :accepted}} =
            connack ->
          {connack, socket}

        {:connack,
         %Packet.Connack{session_present?: session_present?, status: {:refused, _reason}}} =
            connack ->
          connack
      end

      server = self()
      Task.start_link(fn -> read_loop(server, socket) end)

      {:reply, :ok, put_in(state.socket, socket)}
    end
  end

  @impl true
  def handle_call(
        {:receive_packet, packet},
        _from,
        %State{client_id: client_id, inbox: inbox} = state
      ) do
    case packet do
      {:publish_qos0, publish} ->
        {:reply, :ok, put_in(state.inbox, state.inbox ++ [publish])}

      {:publish_qos1, %Packet.Publish{packet_id: packet_id} = publish} ->
        encoded_puback =
          Packet.encode(%Packet.Puback{status: {:accepted, :ok}, packet_id: packet_id})

        :ok = :gen_tcp.send(state.socket, encoded_puback)
        {:reply, :ok, put_in(state.inbox, state.inbox ++ [publish])}

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, state.inbox, state}
  end

  @impl true
  def handle_call({:subscribe, topic_filter: topic_filter, qos: qos}, _from, state) do
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
