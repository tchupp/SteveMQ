defmodule Broker.SubscriptionRegistry do
  use Agent
  require Logger

  def start_link(opts) do
    #    map of topic -> [client_ids]
    #    map of client_id -> [topic]
    name = Keyword.fetch!(opts, :name)
    Agent.start_link(fn -> {%{}, %{}} end, name: name)
  end

  def add_subscription(registry, client_id, topic_filter) do
    Agent.update(
      registry,
      fn {topic_to_clients, client_to_topics} ->
        other_subscribers = Map.get(topic_to_clients, topic_filter)

        topic_to_clients =
          case other_subscribers do
            nil -> Map.put(topic_to_clients, topic_filter, [client_id])
            some -> Map.put(topic_to_clients, topic_filter, some ++ [client_id])
          end

        other_subscribed_topics = Map.get(client_to_topics, client_id)

        client_to_topics =
          case other_subscribed_topics do
            nil -> Map.put(client_to_topics, client_id, [topic_filter])
            some -> Map.put(client_to_topics, client_id, some ++ [topic_filter])
          end

        {topic_to_clients, client_to_topics}
      end
    )
  end

  def remove_subscriptions(registry, client_id) do
    Agent.update(
      registry,
      fn {topic_to_clients, client_to_topics} ->
        {topics, client_to_topics} = Map.pop(client_to_topics, client_id, [])

        topic_to_clients = Map.drop(topic_to_clients, topics)

        {topic_to_clients, client_to_topics}
      end
    )
  end

  def get_subscribers(registry, topic) do
    Agent.get(
      registry,
      fn {topic_to_clients, _} ->
        Map.get(topic_to_clients, topic, [])
      end
    )
  end
end
