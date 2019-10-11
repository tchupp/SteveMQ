defmodule Broker.Command do
  require Logger

  def register_clientid(client_id, pid) do
    fn _ ->
      Logger.info("Registering clientId: #{client_id}")
      Broker.Connection.Registry.register(Broker.Connection.Registry, client_id, pid)
      {:none}
    end
  end

  def send_connack() do
    fn {socket, _} ->
      Logger.info("Sending CONNACK")
      :gen_tcp.send(socket, Packet.Encode.connack())
      {:none}
    end
  end

  def add_subscription(%{topic_filter: topic_filter, packet_id: packet_id}) do
    fn {_, client_id} ->
      Logger.info("received SUBSCRIBE to #{topic_filter}")

      Broker.SubscriptionRegistry.add_subscription(
        Broker.SubscriptionRegistry,
        client_id,
        topic_filter
      )

      {:subscription_added, packet_id}
    end
  end

  def send_suback(packet_id) do
    fn {socket, _} ->
      Logger.info("sending SUBACK")
      :gen_tcp.send(socket, Packet.Encode.suback(packet_id))
      {:none}
    end
  end

  def schedule_publish(%{topic: topic, message: message}) do
    fn {_, client_id} ->
      Logger.info("received PUBLISH to #{topic} from client: #{client_id}")

      subscribers =
        Broker.SubscriptionRegistry.get_subscribers(Broker.SubscriptionRegistry, topic)

      for subscriber <- subscribers do
        Logger.info("scheduling publish for #{subscriber}")
        pid = Broker.Connection.Registry.get_pid(Broker.Connection.Registry, subscriber)
        Broker.Connection.schedule_cmd_external(pid, publish_to_client(topic, message))
      end

      {:none}
    end
  end

  def publish_to_client(topic, message) do
    fn {socket, _} ->
      Logger.info("Publishing to client with msg: #{message}")
      :gen_tcp.send(socket, Packet.Encode.publish(topic, message))
      {:none}
    end
  end

  def log_disconnect() do
    fn {_, client_id} ->
      Logger.info("received DISCONNECT from client id: #{client_id}")
      {:none}
    end
  end

  #  this is totally not sending a disconnect right now, but this works better than not
  def disconnect(socket, error) do
    fn ->
      Logger.info("error reading tcp socket: #{error}")
      :gen_tcp.send(socket, Packet.Encode.connack(:error))
      exit(error)
    end
  end

  def close_connection() do
    fn _ ->
      Logger.info("connection closed. shutting down process")
      exit(:shutdown)
    end
  end
end
