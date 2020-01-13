defmodule Mqtt.Subscription do
  require Logger

  def add_subscription(client_id, topic_filter, pid) do
    {_, :ok} =
      :mnesia.transaction(fn ->
        :mnesia.write({Subscription, client_id, topic_filter, pid})
      end)
  end

  #  returns list of {:online, client_id, pid} | {:offline, client_id}
  def get_subscribers(topic) do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(Subscription, topic, :topic_filter)
      end)

    Enum.map(results, fn {_, client_id, topic, pid} ->
      case pid do
        :none -> {:offline, client_id}
        _ -> {:online, client_id, pid}
      end
    end)
  end

  def mark_offline(client_id) do
    {:atomic, _results} =
      :mnesia.transaction(fn ->
        case :mnesia.wread({Subscription, client_id}) do
          [{_, client_id, topic_filter, _pid}] ->
            :mnesia.write({Subscription, client_id, topic_filter, :none})

          _ ->
            {:atomic, :idk}
        end
      end)
  end

  def mark_online(client_id, pid) do
    {:atomic, _results} =
      :mnesia.transaction(fn ->
        [{_, client_id, topic_filter, _pid}] = :mnesia.wread({Subscription, client_id})
        :mnesia.write({Subscription, client_id, topic_filter, pid})
      end)
  end
end
