defmodule BigTests.PubSubTest do
  use ExUnit.Case
  require Robot

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
    :ok = Robot.start_link()
  end

  test "happy case sub/pub qos0" do
    Robot.start(:subscriber)
    |> Robot.subscribe(topic: "test/topic", qos: 1)

    Robot.start(:publisher)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 0)
    |> Robot.stop()

    Robot.resume(:subscriber)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 0)
    |> Robot.stop()
  end

  test "client with clean start receives publishes while connected" do
    Robot.start(:subscriber)
    |> Robot.subscribe(topic: "test/topic", qos: 1)

    Robot.start(:publisher)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.stop()

    Robot.resume(:subscriber)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.stop()
  end

  test "client with clean start does not receive publishes from old session" do
    Robot.start(:subscriber)
    |> Robot.subscribe(topic: "test/topic", qos: 1)
    |> Robot.stop()

    Robot.start(:publisher)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.stop()

    Robot.start(:subscriber, clean_start: false)
    |> Robot.assert_received_count(0)
    |> Robot.stop()
  end

  test "client with clean start as false receives publishes while disconnected" do
    Robot.start(:subscriber)
    |> Robot.subscribe(topic: "test/topic", qos: 1)
    |> Robot.stop()

    Robot.start(:publisher)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.stop()

    Robot.start(:subscriber, clean_start: false)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.stop()
  end
end
