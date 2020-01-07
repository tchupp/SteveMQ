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
end
