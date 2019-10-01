defmodule Broker.Connection.Registry do
  use GenServer
  require Logger

  def start_link(opts) do
    server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server, opts)
  end

  def get_pid(registry, client_id) do
    GenServer.call(registry, {:get_pid, client_id})
  end

  def register(registry, client_id, pid) do
    GenServer.call(registry, {:register, client_id, pid})
  end

  def remove(registry, client_id) do
    GenServer.call(registry, {:remove, client_id})
  end

  @impl true
  def init(_opts) do
    {:ok, {%{}, %{}}}
  end

  @impl true
  def handle_call({:get_pid, client_id}, _from, state) do
    {clients_to_pids, _} = state
    pid = Map.get(clients_to_pids, client_id)
    {:reply, pid, state}
  end

  @impl true
  def handle_call({:register, client_id, pid}, _from, {client_id_map, monitor_refs}) do
    {:reply, :ok, {Map.put(client_id_map, client_id, pid), monitor_refs}}
  end

  @impl true
  def handle_call({:remove, client_id}, _from, {clients_to_pids, monitor_refs}) do
    {_, new_map} = Map.pop(clients_to_pids, client_id)
    {:reply, :ok, {new_map, monitor_refs}}
  end

end
