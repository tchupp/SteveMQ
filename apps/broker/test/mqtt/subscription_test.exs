defmodule Mqtt.SubscriptionTest do
  use ExUnit.Case
  alias Mqtt.Subscription

  setup do
    :mnesia.clear_table(Subscription)
    :ok
  end

  test "can fetch subscriptions by topic" do
    Subscription.add_subscription("bob", "topic/filter", self())

    subscribers = Subscription.get_subscribers("topic/filter")

    assert subscribers == [{:connected, "bob", self()}]
  end

  test "updates subscriptions with online/offline" do
    Subscription.add_subscription("bob", "topic/filter", self())

    [{_, _, pid}] = Subscription.get_subscribers("topic/filter")
    assert pid == self()

    Subscription.mark_offline("bob")
    [subscriber] = Subscription.get_subscribers("topic/filter")
    assert subscriber == {:offline, "bob"}

    Subscription.mark_online("bob", self())
    [{_, _, pid}] = Subscription.get_subscribers("topic/filter")
    assert pid == self()
  end
end
