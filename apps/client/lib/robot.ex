defmodule Robot do
  import ExUnit.Assertions
  require Logger

  defstruct socket: nil, client_id: nil, topic: nil, qos: nil, received_publishes: []

  def start_link() do
    {:ok, _} = Agent.start_link(fn -> %{} end, name: __MODULE__)
    :ok
  end

  def start(name, clean_start \\ true) do
    {:ok, pid} =
      Client.start_link(%ClientOptions{client_id: Atom.to_string(name), clean_start: clean_start})

    Agent.update(__MODULE__, &Map.put(&1, name, pid))

    pid
  end

  def resume(name) do
    pid = Agent.get(__MODULE__, &Map.get(&1, name))
    pid
  end

  def subscribe(client, topic_filter) do
    :ok = Client.subscribe(client, topic_filter)
    client
  end

  def publish(client, topic: topic, message: message, qos: qos) do
    :ok = Client.publish(client, topic, message, qos)
    client
  end

  def stop(client) do
    Client.stop(client)
    #    {:ok, _pid} = Agent.update(__MODULE__, &Map.pop(&1, name))
    :ok
  end

  def assert_received(
        client,
        topic: expected_topic,
        message: expected_message,
        qos: expected_qos
      ) do
    Process.sleep(2000)

    received_publishes = Client.get_messages(client)

    Logger.warn("pub list size: #{length(received_publishes)}")

    found_publish? =
      received_publishes
      |> Enum.any?(
        &matches_publish?(&1, topic: expected_topic, message: expected_message, qos: expected_qos)
      )

    assert found_publish? == true

    client
  end

  defp matches_publish?(
         %Packet.Publish{topic: topic, message: message, qos: qos},
         topic: expected_topic,
         message: expected_message,
         qos: expected_qos
       ) do
    Logger.warn(
      "matches?: #{topic == expected_topic}, #{message == expected_message}, #{
        qos == expected_qos
      }, "
    )

    topic == expected_topic &&
      message == expected_message &&
      qos == expected_qos
  end

  def assert_received_count(client, expected_received_count) do
    received_publishes = Client.get_messages(client)
    assert(length(received_publishes) == expected_received_count)
    client
  end
end
