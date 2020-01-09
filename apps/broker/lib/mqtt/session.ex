defmodule Mqtt.Session do
  require Logger

  defstruct client_id: nil, inbox: []

  def new_session(client_id) do
    {_, :ok} = :mnesia.transaction(fn ->
      :mnesia.write({Session, client_id, []})
    end)
    %Mqtt.Session{client_id: client_id}
  end

  def continue_session(client_id) do
    {:atomic, results} = :mnesia.transaction(fn ->
      :mnesia.read({Session, client_id})
    end)

    case results do
      [] -> {new_session(client_id), session_present?: false}
      [{_, client_id, inbox}] -> {%Mqtt.Session{client_id: client_id, inbox: inbox}, session_present?: true}
    end
  end

  def queue_message(client_id, pub_id, topic: topic, qos: qos) do
    :mnesia.transaction(fn ->
      [{_, _client_id, inbox}] = :mnesia.wread({Session, client_id})
      :mnesia.write({Session, client_id, inbox ++ [{pub_id, topic: topic, qos: qos}]})
    end)
  end

  def get_queued_messages(client_id) do
    {:atomic, [{_, _client_id, inbox}]} = :mnesia.transaction(fn ->
      :mnesia.read({Session, client_id})
    end)

    inbox
  end

end
