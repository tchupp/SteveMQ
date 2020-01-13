defmodule Broker.Connection.RegistryTest do
  use ExUnit.Case

  setup context do
    _ = start_supervised!({Broker.Connection.Registry, name: context.test})

    Persistence.Mnesia.clear_db()

    %{conn_registry: context.test}
  end

  test "stores pids per client id", %{conn_registry: conn_registry} do
    assert Broker.Connection.Registry.get_pid(conn_registry, "testClientId") == nil

    assert Broker.Connection.Registry.register(conn_registry, "testClientId", self()) == :ok

    assert Broker.Connection.Registry.get_pid(conn_registry, "testClientId") == self()
  end

  test "only saves new pid when another is registered with same client id", %{
    conn_registry: conn_registry
  } do
    Task.async(fn ->
      Broker.Connection.Registry.register(conn_registry, "clientIdThatReconnects", self())
    end)
    |> Task.await()

    assert Broker.Connection.Registry.register(conn_registry, "clientIdThatReconnects", self()) ==
             :ok

    assert Broker.Connection.Registry.get_pid(conn_registry, "clientIdThatReconnects") == self()
  end

  test "removes client from registry if client process goes down", %{conn_registry: conn_registry} do
    Task.async(fn ->
      Broker.Connection.Registry.register(conn_registry, "taskClientId", self())
    end)
    |> Task.await()

    assert Broker.Connection.Registry.get_pid(conn_registry, "taskClientId") == nil
  end

  test "marks subscription offline if client process goes down", %{conn_registry: conn_registry} do
    Mqtt.Subscription.add_subscription("clientIdThatDisconnects", "a/topic", self())

    Task.async(fn ->
      Broker.Connection.Registry.register(conn_registry, "clientIdThatDisconnects", self())
    end)
    |> Task.await()

    assert Broker.Connection.Registry.register(conn_registry, "anotherClientId", self()) == :ok
    assert Mqtt.Subscription.get_subscribers("a/topic") == [{:offline, "clientIdThatDisconnects"}]
  end
end
