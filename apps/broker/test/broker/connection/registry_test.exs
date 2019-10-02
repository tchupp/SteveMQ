defmodule Broker.Connection.RegistryTest do
  use ExUnit.Case, async: true

  setup context do
    _ = start_supervised!({Broker.Connection.Registry, name: context.test})
    %{registry: context.test}
  end

  test "stores pids per client id", %{registry: registry} do
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == nil

    Broker.Connection.Registry.register(registry, "testClientId", self())
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == self()
  end

  test "deletes values by key", %{registry: registry} do
    Broker.Connection.Registry.register(registry, "mqttClientOfSomeSort", self())

    assert Broker.Connection.Registry.remove(registry, "mqttClientOfSomeSort") == :ok
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

  test "removes client from registry if client process goes down", %{registry: registry} do
    task =
      Task.async(fn ->
        Broker.Connection.Registry.register(registry, "taskClientId", self())
      end)
    Task.await(task)

    assert Broker.Connection.Registry.get_pid(registry, "taskClientId") == nil
  end
end
