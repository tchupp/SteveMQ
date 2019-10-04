defmodule Broker.SubscriptionRegistry do
  use Agent
  require Logger

  def start_link(opts) do
    #    map of topic -> [client_ids]
    name = Keyword.fetch!(opts, :name)
    Agent.start_link(fn -> %{} end, name: name)
  end

  def add_subscription(registry, client_id, topic) do
    Agent.update(
      registry,
      fn state ->
        other_clients = Map.get(state, topic)

        case other_clients do
          nil -> Map.put(state, topic, [client_id])
          some -> Map.put(state, topic, some ++ [client_id])
        end
      end
    )
  end

  def remove_subscription(registry, client_id, topic) do
    Agent.update(
      registry,
      fn state ->
        clients = Map.get(state, topic)

        case clients do
          nil -> state
          some -> Map.put(state, topic, some -- [client_id])
        end
      end
    )
  end

  def get_subscribers(registry, topic) do
    case Agent.get(registry, &Map.get(&1, topic)) do
      nil -> []
      some -> some
    end
  end
end
