defmodule BigTests.PubSubTest do
  use ExUnit.Case
  require Robot

  setup do
    Application.stop(:broker)
    :ok = Application.start(:broker)
  end

  test "happy case sub/pub qos0" do
    Robot.new_subscriber(client_id: "subscriber", topic: "test/topic", qos: 1)
    |> Robot.connect(clean_start: true)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 0)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 0)
    |> Robot.disconnect()
  end

  test "client with clean start receives publishes while connected" do
    Robot.new_subscriber(client_id: "subscriber", topic: "test/topic", qos: 1)
    |> Robot.connect(clean_start: true)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.disconnect()
  end

  test "client with clean start does not receive publishes while disconnected" do
    Robot.new_subscriber(client_id: "subscriber", topic: "test/topic", qos: 1)
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.connect(clean_start: true)
    |> Robot.assert_received_count(0)
    |> Robot.disconnect()
  end

  test "client with clean start as false receives publishes while disconnected" do
    Robot.new_subscriber(client_id: "subscriber", topic: "test/topic", qos: 1)
    |> Robot.connect(clean_start: true)
    |> Robot.disconnect()
    |> Robot.publish(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.connect(clean_start: false)
    |> Robot.assert_received(topic: "test/topic", message: "hi there", qos: 1)
    |> Robot.disconnect()
  end
end
