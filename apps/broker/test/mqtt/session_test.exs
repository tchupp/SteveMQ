defmodule Mqtt.SessionTest do
  use ExUnit.Case
  alias Mqtt.Session

  setup do
    # TODO: why does this always return `{:aborted, {:no_exists, Session}}`?
    {:aborted, {:no_exists, Session}} = :mnesia.clear_table(Session)
    :ok
  end

  test "adds queued messages to session for a client" do
    Session.new_session("bob")
    Session.queue_message("bob", pub_id: 2, packet_id: 12, topic: "carl/topic", qos: 1)
    Session.queue_message("bob", pub_id: 7, packet_id: 13, topic: "bob/topic", qos: 0)

    queued_messages = Session.get_queued_messages("bob")

    assert queued_messages == [
             {2, packet_id: 12, topic: "carl/topic", qos: 1},
             {7, packet_id: 13, topic: "bob/topic", qos: 0}
           ]
  end

  test "continue session returns existing session" do
    Session.new_session("bob")
    Session.queue_message("bob", pub_id: 2, packet_id: 22, topic: "carl/topic", qos: 1)

    existing_session = Session.continue_session("bob")

    assert existing_session ==
             {
               %Session{
                 client_id: "bob",
                 inbox: [{2, packet_id: 22, topic: "carl/topic", qos: 1}]
               },
               session_present?: true
             }
  end

  test "continue session starts new session if one doesn't exist" do
    new_session = Session.continue_session("nobody")

    assert new_session == {
             %Session{client_id: "nobody", inbox: []},
             session_present?: false
           }
  end

  test "removes delivered messages from session" do
    Session.new_session("bob")

    Session.queue_message("bob", pub_id: 5, packet_id: 55, topic: "a/topic", qos: 1)
    Session.queue_message("bob", pub_id: 6, packet_id: 66, topic: "a/topic", qos: 1)
    {:ok, pub_id} = Session.mark_delivered("bob", 55)

    assert pub_id == 5

    assert Session.get_queued_messages("bob") == [
             {6, packet_id: 66, topic: "a/topic", qos: 1}
           ]
  end
end
