defmodule Mqtt.QueuedMessage do
  require Logger

  def store_payload(id, payload, client_id) do
    {_, :ok} =
      :mnesia.transaction(fn ->
        result = :mnesia.wread({PublishPayload, id})

        case result do
          [] ->
            :mnesia.write({PublishPayload, id, payload, [client_id]})

          [{_, id, payload, client_refs}] ->
            :mnesia.write({PublishPayload, id, payload, client_refs ++ [client_id]})

          _ ->
            {}
        end
      end)

    :ok
  end

  def get_payload(pub_id) do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        :mnesia.read({PublishPayload, pub_id})
      end)

    case results do
      [] ->
        nil

      [{_, _id, payload, _ref_count}] ->
        payload

      [head | tail] ->
        Logger.warn("Found multiple payloads. pub_id=#{pub_id}")
        nil
    end
  end

  def mark_delivered(client_id, pub_id) do
    {:atomic, _results} =
      :mnesia.transaction(fn ->
        case :mnesia.wread({PublishPayload, pub_id}) do
          [] ->
            nil

          [{_, id, payload, refs}] ->
            new_refs = refs -- [client_id]

            case new_refs do
              [] -> :mnesia.delete({PublishPayload, pub_id})
              _some -> :mnesia.write({PublishPayload, id, payload, new_refs})
            end
        end
      end)

    :ok
  end
end
