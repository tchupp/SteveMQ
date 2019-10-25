defmodule BigTests.PubSubTest do
  use ExUnit.Case

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
  end

  test "happy case sub/pub qos0" do
    pid = Task.async(fn ->
      Client.subscribe_1msg("dr_subscribe", "test/topic")
    end)

    Process.sleep(300)
    :ok = Client.publish("mr_publish_jr", "helloooo", "test/topic")

    msg = Task.await(pid)
    assert msg == "helloooo"
  end

end
