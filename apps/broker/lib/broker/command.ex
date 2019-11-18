defmodule Broker.Command do
  require Logger

  alias Packet.Connack

  @doc """
    - Return {:none} from commands to report no events
    - Otherwise, Events look like this: {<event type atom>, <optional: more stuff>}

    - Commands return closures with arity:1, which accept connection state
  """

  def register_clientid(client_id, pid) do
    fn _ ->
      Logger.debug("Registering clientId: #{client_id}")
      Broker.Connection.Registry.register(Broker.Connection.Registry, client_id, pid)
      {:none}
    end
  end

  def start_new_session(client_id) do
    fn _ ->
      Logger.debug("Starting new session for #{client_id}")
      Broker.SessionRepo.new_session(client_id, :never)
      {:session_started, session_present?: false}
    end
  end

  def continue_session(client_id) do
    fn _ ->
      Logger.debug("Continuing session for #{client_id}")
      session = Broker.SessionRepo.get_session(client_id)

      case session do
        [] ->
          Logger.debug("Found no session for #{client_id}")
          Broker.SessionRepo.new_session(client_id, :never)
          {:session_started, session_present?: false}

        _ ->
          {:session_started, session_present?: true}
      end
    end
  end

  def send_connack({_, session_present?: session_present?}) do
    fn {socket, _} ->
      Logger.info("Sending CONNACK, session present: #{session_present?}")

      :gen_tcp.send(
        socket,
        Packet.encode(%Connack{session_present?: session_present?, status: :accepted})
      )

      {:none}
    end
  end

  def send_puback(packet_id) do
    fn {socket, _} ->
      Logger.info("Sending PUBACK. packet_id: #{packet_id}")

      :gen_tcp.send(
        socket,
        Packet.encode(%Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}})
      )

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
      :gen_tcp.send(socket, Packet.encode(%Packet.Suback{packet_id: packet_id, acks: []}))
      {:none}
    end
  end

  def schedule_publish(%Packet.Publish{topic: topic, message: message} = publish) do
    fn {_, client_id} ->
      Logger.info("received PUBLISH to #{topic} from client: #{client_id}")

      subscribers =
        Broker.SubscriptionRegistry.get_subscribers(Broker.SubscriptionRegistry, topic)

      for subscriber <- subscribers do
        pid = Broker.Connection.Registry.get_pid(Broker.Connection.Registry, subscriber)
        Broker.Connection.schedule_cmd_external(pid, publish_to_client(publish))
      end

      {:none}
    end
  end

  def publish_to_client(%Packet.Publish{message: message} = publish) do
    fn {socket, client_id} ->
      Logger.info("Publishing to client #{client_id} with msg: #{message}")
      :gen_tcp.send(socket, Packet.encode(publish))
      {:none}
    end
  end

  def log_disconnect() do
    fn {_, client_id} ->
      Logger.info("received DISCONNECT. client id: #{client_id}")
      {:none}
    end
  end

  def send_pingresp() do
    fn {socket, client_id} ->
      Logger.info("sending PINGRESP. client id: #{client_id}")
      :gen_tcp.send(socket, Packet.encode(%Packet.Pingresp{}))
      {:none}
    end
  end

  def send_disconnect(error) do
    fn _ ->
      Logger.info("error reading tcp socket")
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
