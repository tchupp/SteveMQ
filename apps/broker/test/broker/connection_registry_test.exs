defmodule Broker.ConnectionRegistryTest do
  use ExUnit.Case, async: true

  setup do
    registry = start_supervised!(Broker.ConnectionRegistry)
    %{registry: registry}
  end

  test "stores pids per client id", %{registry: registry} do
    assert Broker.ConnectionRegistry.get_pid(registry, "testClientId") == nil

    Broker.ConnectionRegistry.register(registry, "testClientId", self())
    assert Broker.ConnectionRegistry.get_pid(registry, "testClientId") == self()
  end

  test "deletes values by key", %{registry: registry} do
    Broker.ConnectionRegistry.register(registry, "mqttClientOfSomeSort", self())

    assert Broker.ConnectionRegistry.remove(registry, "mqttClientOfSomeSort") == self()
    assert Broker.ConnectionRegistry.get_pid(registry, "mqttClientOfSomeSort") == nil
  end
end
