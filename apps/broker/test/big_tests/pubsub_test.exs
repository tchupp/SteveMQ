defmodule BigTests.PubSubTest do
  use ExUnit.Case
  require Robot

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
    :ok = Robot.start_link()
  end

  describe "qos 0" do
    test "subscriber with clean start receives publishes while connected" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there", qos: 0)
      |> Robot.stop()

      Robot.resume(:subscriber)
      |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 0)
      |> Robot.stop()
    end

    test "subscriber with clean start as true does NOT receive publishes when continuing the session" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)
      |> Robot.stop()

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there", qos: 0)
      |> Robot.stop()

      Robot.start(:subscriber, clean_start: false)
      |> Robot.assert_received_count(0)
      |> Robot.stop()
    end

    test "subscriber with clean start as true does NOT receive publishes from old session" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)
      |> Robot.stop()

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there", qos: 0)
      |> Robot.stop()

      Robot.start(:subscriber, clean_start: true)
      |> Robot.assert_received_count(0)
      |> Robot.stop()
    end
  end

  describe "qos 1" do
    test "subscriber with clean start receives publishes while connected, in order of publish" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
      |> Robot.stop()

      Robot.resume(:subscriber)
      |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 1)
      |> Robot.stop()
    end

    test "subscriber with clean start as true does NOT receive publishes from old session" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)
      |> Robot.stop()

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
      |> Robot.stop()

      Robot.start(:subscriber, clean_start: true)
      |> Robot.assert_received_count(0)
      |> Robot.stop()
    end

    test "subscriber with clean start as false does receive publishes while disconnected" do
      Robot.start(:subscriber)
      |> Robot.subscribe(topic: "test/topic", qos: 1)
      |> Robot.stop()

      Robot.start(:publisher)
      |> Robot.publish(topic: "test/topic", message: "hi there 1", qos: 1)
      |> Robot.publish(topic: "test/topic", message: "hi there 2", qos: 1)
      |> Robot.stop()

      Robot.start(:subscriber, clean_start: false)
      |> Robot.assert_received(index: 0, topic: "test/topic", message: "hi there 1", qos: 1)
      |> Robot.assert_received(index: 1, topic: "test/topic", message: "hi there 2", qos: 1)
      |> Robot.stop()
    end
  end
end
