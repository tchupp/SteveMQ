defmodule Broker.Connection.RegistryTest do
  use ExUnit.Case

  setup context do
    _ = start_supervised!({Broker.Connection.Registry, name: context.test})
    #    TODO: We can't start out own test registry because the SubscriptionRegistry is hardcoded right now. We need to pass the name in via child_spec args
    #    _ = start_supervised!({Broker.SubscriptionRegistry, name: Broker.SubscriptionRegistry})

    %{conn_registry: context.test, sub_registry: Broker.SubscriptionRegistry}
  end

  test "stores pids per client id", %{conn_registry: conn_registry} do
    assert Broker.Connection.Registry.get_pid(conn_registry, "testClientId") == nil

    assert Broker.Connection.Registry.register(conn_registry, "testClientId", self()) == :ok

    assert Broker.Connection.Registry.get_pid(conn_registry, "testClientId") == self()
  end

  test "only saves new pid when another is registered with same client id", %{conn_registry: conn_registry} do
    Task.async(fn -> Broker.Connection.Registry.register(conn_registry, "clientIdThatReconnects", self())end)
    |> Task.await()

    assert Broker.Connection.Registry.register(conn_registry, "clientIdThatReconnects", self()) == :ok

    assert Broker.Connection.Registry.get_pid(conn_registry, "clientIdThatReconnects") == self()
  end

  test "removes client from registry if client process goes down", %{conn_registry: conn_registry} do
    Task.async(fn -> Broker.Connection.Registry.register(conn_registry, "taskClientId", self())end)
    |> Task.await()

    assert Broker.Connection.Registry.get_pid(conn_registry, "taskClientId") == nil
  end

  test "removes subscription if client process goes down",
       %{conn_registry: conn_registry, sub_registry: sub_registry} do
    Broker.SubscriptionRegistry.add_subscription(sub_registry, "clientIdThatDisconnects", "a/topic")

    Task.async(fn -> Broker.Connection.Registry.register(conn_registry, "clientIdThatDisconnects", self()) end)
    |> Task.await()

    assert Broker.Connection.Registry.register(conn_registry, "anotherClientId", self()) == :ok

    assert Broker.SubscriptionRegistry.get_subscribers(sub_registry, "a/topic") == []
  end
end
