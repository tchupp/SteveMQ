defmodule Broker.Connection do
  use GenServer, restart: :temporary
  require Logger

  # client

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def fire_event_external(server, packet) do
    GenServer.call(server, {:event_external, packet})
  end

  def schedule_cmd_external(server, cmd) do
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
        :ok = fire_event_external(server, packet)
        read_loop(server, socket)

      {:error, :closed} ->
        :ok = fire_event_external(server, {:connection_closed})
    end
  end

  defp fire_event_internal(event) do
    case event do
      {:none} -> nil
      _ -> GenServer.cast(self(), {:event_internal, event})
    end
  end

  defp schedule_commands_internal(commands) when is_list(commands) do
    for cmd <- commands do
      GenServer.cast(self(), {:cmd_internal, cmd})
    end
  end

  @impl true
  def handle_call({:event_external, event}, _from, state) do
    fire_event_internal(event)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:cmd_external, command}, _from, state) do
    event = command.(state)
    fire_event_internal(event)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:event_internal, event}, state) do
    {state, commands} = Mqtt.Update.update(event, state)
    schedule_commands_internal(commands)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cmd_internal, command}, state) do
    event = command.(state)
    fire_event_internal(event)
    {:noreply, state}
  end
end
