defmodule Mqtt.SessionTest do
  use ExUnit.Case
  alias Mqtt.Session

  setup do
    :mnesia.clear_table(Session)
    :ok
  end

  test "adds queued messages to session for a client" do
    Session.new_session("bob")
    Session.queue_message("bob", 2, topic: "carl/topic", qos: 1)
    Session.queue_message("bob", 7, topic: "bob/topic", qos: 0)

    queued_messages = Session.get_queued_messages("bob")

    assert queued_messages == [
             {2, topic: "carl/topic", qos: 1},
             {7, topic: "bob/topic", qos: 0}
           ]
  end

end
