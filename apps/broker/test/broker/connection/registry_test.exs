defmodule Broker.Connection.RegistryTest do
  use ExUnit.Case

  setup context do
    _ = start_supervised!({Broker.Connection.Registry, name: context.test})
    %{registry: context.test}
  end

  test "stores pids per client id", %{registry: registry} do
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == nil

    Broker.Connection.Registry.register(registry, "testClientId", self())
    assert Broker.Connection.Registry.get_pid(registry, "testClientId") == self()
  end

  test "only saves new pid when another is registered with same client id", %{registry: registry} do
    task =
      Task.async(
        fn ->
          Broker.Connection.Registry.register(registry, "clientIdThatReconnects", self())
        end
      )

    Task.await(task)

    Broker.Connection.Registry.register(registry, "clientIdThatReconnects", self())

    assert Broker.Connection.Registry.get_pid(registry, "clientIdThatReconnects") == self()
  end

  test "removes client from registry if client process goes down", %{registry: registry} do
    Task.await(
      Task.async(
        fn ->
          Broker.Connection.Registry.register(registry, "taskClientId", self())
        end
      )
    )

    assert Broker.Connection.Registry.get_pid(registry, "taskClientId") == nil
  end


  @tag :skip
  test "removes subscription if client process goes down", %{registry: registry} do
    Broker.SubscriptionRegistry.add_subscription(:sub_registry, "taskClientId", "a/topic")

    Task.await(
      Task.async(
        fn ->
          Broker.Connection.Registry.register(registry, "taskClientId", self())
        end
      )
    )

    assert Broker.SubscriptionRegistry.get_subscribers(:sub_registry, "a/topic") == []
  end
end
