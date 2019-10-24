defmodule BigTests.PubSubTest do
  use ExUnit.Case

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
  end

  test "happy case sub/pub qos0" do
#    pid = Task.async(fn ->
#      Client.subscribe_1msg("clientId", "test/topic", 0)
#    end)
#
#    :ok = Client.publish("clientId", "test/topic", 0)
#
#    _msg = Task.await(pid)
  end

end
