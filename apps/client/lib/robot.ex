defmodule Robot do
  import ExUnit.Assertions
  require Logger

  defstruct name: nil

  def start_link() do
    children = [
      {Registry, [keys: :unique, name: Client.Bucket]}
    ]

    opts = [strategy: :one_for_one, name: Robot]
    {:ok, _} = Supervisor.start_link(children, opts)

    :ok
  end

  def start(name) do
    start(name, clean_start: true)
  end

  def start(name, clean_start: clean_start) do
    {:ok, pid} = Client.start_link(%ClientOptions{client_id: name, clean_start: clean_start})

    :ok = Client.connect(name, client_id: name, clean_start: clean_start)

    %Robot{name: name}
  end

  def resume(name) do
    %Robot{name: name}
  end

  def subscribe(%Robot{name: name} = robot_context, topic: topic_filter, qos: qos) do
    :ok = Client.subscribe(name, topic_filter: topic_filter, qos: qos)
    robot_context
  end

  def publish(%Robot{name: name} = robot_context, topic: topic, message: message, qos: qos) do
    :ok = Client.publish(name, topic, message, qos)
    robot_context
  end

  def assert_received_count(%Robot{name: name} = robot_context, expected_received_count) do
    received_publishes = Client.get_messages(name)
    assert(length(received_publishes) == expected_received_count)
    robot_context
  end

  defp via_name(client_id) do
    Client.Bucket.via_name(__MODULE__, client_id)
  end

  def stop(%Robot{name: name} = _robot_context) do
    :ok = Client.stop(name)
    :ok = Client.Bucket.delete_meta(name)
    :ok
  end

  def assert_received(
        %Robot{name: name} = robot_context,
        topic: expected_topic,
        message: expected_message,
        qos: expected_qos
      ) do
    Process.sleep(2000)

    received_publishes = Client.get_messages(name)

    found_publish? =
      received_publishes
      |> Enum.any?(
        &matches_publish?(&1, topic: expected_topic, message: expected_message, qos: expected_qos)
      )

    assert found_publish? == true

    robot_context
  end

  defp matches_publish?(
         %Packet.Publish{topic: topic, message: message, qos: qos},
         topic: expected_topic,
         message: expected_message,
         qos: expected_qos
       ) do
    topic == expected_topic &&
      message == expected_message &&
      qos == expected_qos
  end
end
