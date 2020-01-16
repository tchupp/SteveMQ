defmodule Mqtt.QueuedMessageTest do
  use ExUnit.Case
  alias Mqtt.QueuedMessage

  setup do
    :mnesia.clear_table(PublishPayload)
    :ok
  end

  test "saves queued message payloads" do
    pub_id = make_ref()
    QueuedMessage.store_payload(pub_id, {"a payload"}, "bob")

    payload = QueuedMessage.get_payload(pub_id)
    assert payload == {"a payload"}
  end

  test "deletes payloads once ref_count reaches zero" do
    pub_id = make_ref()
    QueuedMessage.store_payload(pub_id, {"somestuff"}, "client1")
    QueuedMessage.store_payload(pub_id, {"somestuff"}, "client2")
    QueuedMessage.store_payload(pub_id, {"somestuff"}, "client3")

    :ok = QueuedMessage.mark_delivered("client1", pub_id)
    :ok = QueuedMessage.mark_delivered("client2", pub_id)
    payload = QueuedMessage.get_payload(pub_id)
    assert payload == {"somestuff"}

    :ok = QueuedMessage.mark_delivered("client3", pub_id)
    payload = QueuedMessage.get_payload(pub_id)
    assert payload == nil
  end
end
