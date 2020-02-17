defmodule Client do
  use GenServer

  alias Connection.Inflight
  alias Connection.Receiver

  @opaque t :: %__MODULE__{
            client_id: String.t(),
            opts: ClientOptions.t()
          }

  defstruct client_id: nil, opts: nil, socket: nil, inbox: []

  alias __MODULE__, as: State

  # client

  def start_link(%ClientOptions{client_id: client_id} = opts) do
    {:ok, _pid} = Inflight.start_link(client_id: client_id)
    {:ok, _pid} = Receiver.start_link(client_id: client_id)
    GenServer.start_link(__MODULE__, opts, name: via_name(client_id))
  end

  def connect(name, clean_start: clean_start) do
    GenServer.call(via_name(name), {:connect, clean_start: clean_start})
  end

  def receive_packet(name, packet) do
    GenServer.call(via_name(name), {:receive_packet, packet})
  end

  def get_messages(name) do
    GenServer.call(via_name(name), :get_messages)
  end

  def subscribe(name, topic_filter, qos, timeout \\ :infinity) do
    {:ok, ref} = GenServer.call(via_name(name), {:subscribe, topics: [{topic_filter, qos}]})
    Inflight.await(name, ref, timeout)
  end

  def publish(name, topic, message, qos) when qos == 0 do
    GenServer.call(via_name(name), {:publish, message, topic, qos})
  end

  def publish(name, topic, message, qos, timeout \\ :infinity) do
    {:ok, ref} = GenServer.call(via_name(name), {:publish, message, topic, qos})
    Inflight.await(name, ref, timeout)
  end

  def stop(name) do
    GenServer.stop(via_name(name))
    Receiver.stop(name)
    Inflight.stop(name)
  end

  defp via_name(client_id) do
    Client.Bucket.via_name(__MODULE__, client_id)
  end

  # server

  @impl true
  def init(%ClientOptions{client_id: client_id} = opts) do
    {:ok, %State{client_id: client_id, opts: opts}}
  end

  @impl true
  def handle_call(
        {:connect, clean_start: clean_start},
        _from,
        %Client{client_id: client_id, opts: opts, socket: nil} = state
      ) do
    with {:ok, socket} = :gen_tcp.connect(opts.host, opts.port, [:binary, active: false]),
         :ok =
           :gen_tcp.send(
             socket,
             Packet.encode(%Packet.Connect{client_id: client_id, clean_start: clean_start})
           ),
         {:ok, raw_packet} <- :gen_tcp.recv(socket, 0, 5000) do
      case Packet.decode(raw_packet) do
        {:connack, %Packet.Connack{status: :accepted}} = connack ->
          {connack, socket}

        {:connack, %Packet.Connack{status: {:refused, _reason}}} = connack ->
          connack
      end

      :ok = Receiver.handle_socket(client_id, socket)
      :ok = Inflight.connect(client_id, socket)

      {:reply, :ok, put_in(state.socket, socket)}
    end
  end

  @impl true
  def handle_call(
        {:receive_packet, packet},
        _from,
        %State{client_id: client_id} = state
      ) do
    case packet do
      {_type, %Packet.Publish{} = publish} ->
        :ok = Inflight.receive(client_id, publish)
        {:reply, :ok, put_in(state.inbox, state.inbox ++ [publish])}

      {:puback, %Packet.Puback{} = puback} ->
        :ok = Inflight.receive(client_id, puback)
        {:reply, :ok, state}

      {:suback, %Packet.Suback{} = suback} ->
        :ok = Inflight.receive(client_id, suback)
        {:reply, :ok, state}

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, state.inbox, state}
  end

  @impl true
  def handle_call(
        {:subscribe, topics: topics},
        {pid, ref} = _from,
        %State{client_id: client_id} = state
      ) do
    subscribe = %Packet.Subscribe{topics: topics}
    {:ok, ref} = Inflight.track_outgoing(client_id, subscribe, pid, ref)
    {:reply, {:ok, ref}, state}
  end

  @impl true
  def handle_call(
        {:publish, message, topic, qos},
        {pid, ref} = _from,
        %State{client_id: client_id} = state
      ) do
    publish = %Packet.Publish{topic: topic, message: message, qos: qos}
    {:ok, ref} = Inflight.track_outgoing(client_id, publish, pid, ref)
    {:reply, {:ok, ref}, state}
  end
end
