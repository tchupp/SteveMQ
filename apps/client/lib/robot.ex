defmodule Robot do
  import ExUnit.Assertions

  defstruct socket: nil, client_id: nil, topic: nil, qos: nil, received_publishes: []

  def for(_name) do
  end

  def connect(%Robot{client_id: client_id, topic: topic} = robot_context,
        clean_start: clean_start
      ) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    :ok = Client.connect(socket, client_id, clean_start)
    %Robot{robot_context | socket: socket}
  end

  def disconnect(%Robot{socket: socket} = robot_context) do
    :ok = :gen_tcp.close(socket)
    %Robot{robot_context | socket: nil}
  end

  def publish(%Robot{} = robot_context, topic: topic, message: message, qos: qos) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 1883, opts)

    robot_context
  end

  def assert_received(%Robot{received_publishes: received_publishes} = robot_context,
        topic: expected_topic,
        message: expected_message,
        qos: expected_qos
      ) do
    found_publish? =
      received_publishes
      |> Enum.any?(
        &matches_publish?(&1, topic: expected_topic, message: expected_message, qos: expected_qos)
      )

    assert found_publish? == true

    robot_context
  end

  defp matches_publish?(%Packet.Publish{topic: topic, message: message, qos: qos},
         topic: expected_topic,
         message: expected_message,
         qos: expected_qos
       ) do
    topic == expected_topic &&
      message == expected_message &&
      qos == expected_qos
  end

  def assert_received_count(
        %Robot{received_publishes: received_publishes} = robot_context,
        expected_received_count
      ) do
    assert(length(received_publishes) == expected_received_count)
    robot_context
  end
end
