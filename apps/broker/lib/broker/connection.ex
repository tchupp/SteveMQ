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

  def schedule_cmd(server, cmd) do
    GenServer.call(server, {:cmd_external, cmd})
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
        packet = Packet.Decode.parse(raw_packet)
        :ok = process_incoming(server, packet)
        read_loop(server, socket)

      {:error, :closed} ->
        :ok = process_incoming(server, {:connection_closed})
    end
  end

  defp fire_event(event) do
    GenServer.cast(self(), {:event, event})
  end

  @impl true
  def handle_call({:process_incoming, event}, _from, state) do
    fire_event(event)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    {state, commands} = Mqtt.Update.update(event, state)

    for command <- commands do
      GenServer.cast(self(), {:cmd, command})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:cmd, command}, state) do
    event = command.(state)

    case event do
      {type, _} when type != :none ->
        fire_event(event)

      _ ->
        nil
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:cmd_external, command}, _from, state) do
    event = command.(state)

    case event do
      {type, _} when type != :none ->
        fire_event(event)
      _ ->
        nil
    end

    {:reply, :ok, state}
  end

end
