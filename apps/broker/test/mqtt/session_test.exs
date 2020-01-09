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

  test "continue session returns existing session" do
    Session.new_session("bob")
    Session.queue_message("bob", 2, topic: "carl/topic", qos: 1)

    existing_session = Session.continue_session("bob")

    assert existing_session == {%Session{client_id: "bob", inbox: [{2 , topic: "carl/topic", qos: 1}]}, session_present?: true}
  end

  test "continue session starts new session if one doesn't exist" do
    new_session = Session.continue_session("nobody")

    assert new_session == {%Session{client_id: "nobody", inbox: []}, session_present?: false}
  end

end
