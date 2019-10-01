defmodule Broker.Connection.RegistryTest do
  use ExUnit.Case, async: true

  setup do
    registry = start_supervised!(Broker.Connection.Registry)
    %{registry: registry}
  end

  test "stores pids per client id", %{registry: registry} do
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == nil

    Broker.Connection.Registry.register(registry, "testClientId", self())
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == self()
  end

  test "deletes values by key", %{registry: registry} do
    Broker.Connection.Registry.register(registry, "mqttClientOfSomeSort", self())

    assert Broker.Connection.Registry.remove(registry, "mqttClientOfSomeSort") == self()
    assert Broker.Connection.Registry.get_pid(registry, "mqttClientOfSomeSort") == nil
  end

  test "only saves new pid when another is registered with same client id", %{registry: registry} do
    task =
      Task.async(fn ->
        Broker.Connection.Registry.register(registry, "clientIdThatReconnects", self())
      end)

    Task.await(task)

    Broker.Connection.Registry.register(registry, "clientIdThatReconnects", self())

    assert Broker.Connection.Registry.get_pid(registry, "clientIdThatReconnects") == self()
  end
end
