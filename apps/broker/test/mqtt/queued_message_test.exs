defmodule Mqtt.QueuedMessageTest do
  use ExUnit.Case
  alias Mqtt.QueuedMessage

  setup do
    :mnesia.clear_table(PublishPayload)
    :ok
  end

  test "saves queued message payloads" do
    id = QueuedMessage.store_payload({"somestuff"}, 3)
    payload = QueuedMessage.get_payload(id)
    assert payload == {"somestuff"}
  end

  test "deletes payloads once ref_count reaches zero" do
    id = QueuedMessage.store_payload({"somestuff"}, 3)
    payload = QueuedMessage.get_payload(id)

    QueuedMessage.mark_delivered(id)
    QueuedMessage.mark_delivered(id)
    assert payload == {"somestuff"}

    QueuedMessage.mark_delivered(id)
    payload = QueuedMessage.get_payload(id)
    assert payload == nil
  end

end
