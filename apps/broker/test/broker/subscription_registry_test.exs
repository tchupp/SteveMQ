defmodule Broker.SubscriptionRegistryTest do
  use ExUnit.Case, async: true

  setup do
    registry = start_supervised!(Broker.SubscriptionRegistry)
    %{registry: registry}
  end

  test "keeps track of each client subscribed to a topic", %{registry: registry} do
    assert Broker.SubscriptionRegistry.get_subscribers(registry, "a/topic") == nil

    Broker.SubscriptionRegistry.add_subscription(registry, "client1", "a/topic")
    Broker.SubscriptionRegistry.add_subscription(registry, "client2", "a/topic")

    clients = Broker.SubscriptionRegistry.get_subscribers(registry, "a/topic")
    assert length(clients) == 2
    assert Enum.at(clients, 0) == "client1"
    assert Enum.at(clients, 1) == "client2"
  end

  test "removes client ids from topics", %{registry: registry} do
    Broker.SubscriptionRegistry.add_subscription(registry, "client1", "b/topic")
    Broker.SubscriptionRegistry.add_subscription(registry, "client2", "b/topic")

    Broker.SubscriptionRegistry.remove_subscription(registry, "client1", "b/topic")

    clients = Broker.SubscriptionRegistry.get_subscribers(registry, "b/topic")
    assert length(clients) == 1
    assert Enum.at(clients, 0) == "client2"
  end

  test "can add to subscriptions that were previously emptied", %{registry: registry} do
    Broker.SubscriptionRegistry.add_subscription(registry, "client1", "c/topic")
    Broker.SubscriptionRegistry.remove_subscription(registry, "client1", "c/topic")

    Broker.SubscriptionRegistry.add_subscription(registry, "client2", "c/topic")

    clients = Broker.SubscriptionRegistry.get_subscribers(registry, "c/topic")
    assert length(clients) == 1
    assert Enum.at(clients, 0) == "client2"
  end
end
