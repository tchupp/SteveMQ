defmodule Broker.Connection.Registry do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  def get_pid(registry, client_id) do
    Agent.get(registry, & &1[client_id])
  end

  def register(registry, client_id, pid) do
    Agent.update(registry, &Map.put(&1, client_id, pid))
  end

  def remove(registry, client_id) do
    Agent.get_and_update(registry, &Map.pop(&1, client_id))
  end
end
