defmodule Mqtt.QueuedMessage do
  require Logger

#  return id
  def store_payload(payload, ref_count) do
    id = make_ref()
    {_, :ok} = :mnesia.transaction(fn ->
      :mnesia.write({PublishPayload, id, payload, ref_count})
    end)

    id
  end

#  return payload, count
  def get_payload(pub_id) do
    {:atomic, results} = :mnesia.transaction(fn ->
      :mnesia.read({PublishPayload, pub_id})
    end)

    case results do
      [{_, _id, payload, _ref_count}] -> payload
      _ -> nil
    end
  end

  def mark_delivered(pub_id) do
    {:atomic, _results} = :mnesia.transaction(fn ->
      [{_, id, payload, ref_count}] = :mnesia.wread({PublishPayload, pub_id})

      case ref_count do
        1 -> :mnesia.delete({PublishPayload, pub_id})
        _ -> :mnesia.write({PublishPayload, id, payload, ref_count-1})
      end
    end)
  end

end
