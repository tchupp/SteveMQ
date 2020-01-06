defmodule Broker.Command do
  require Logger

  alias Packet.Connack
  alias Mqtt.Update.State

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
    fn state ->
      Logger.info("Sending CONNACK, session present: #{session_present?}")

      :gen_tcp.send(
        state.socket,
        Packet.encode(%Connack{session_present?: session_present?, status: :accepted})
      )

      {:none}
    end
  end

  def send_puback(packet_id) do
    fn state ->
      Logger.info("Sending PUBACK. packet_id: #{packet_id}")

      :gen_tcp.send(
        state.socket,
        Packet.encode(%Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}})
      )

      {:none}
    end
  end

  def add_subscription(%Packet.Subscribe{topics: topics, packet_id: packet_id}) do
    fn state ->
      for {topic_filter, qos} <- topics do
        Logger.info(
          "received SUBSCRIBE. client_id=#{state.client_id} topic_filter=#{topic_filter} qos=#{qos}"
        )

        Broker.SubscriptionRegistry.add_subscription(
          Broker.SubscriptionRegistry,
          state.client_id,
          topic_filter
        )
      end

      {
        :subscription_added,
        %{
          acks: topics
                |> Enum.map(fn {_topic, qos} -> {:ok, qos} end),
          packet_id: packet_id
        }
      }
    end
  end

  def send_suback(%{acks: acks, packet_id: packet_id}) do
    fn state ->
      Logger.info("sending SUBACK. client_id=#{state.client_id} packet_id=#{packet_id}")

      suback = %Packet.Suback{
        packet_id: packet_id,
        acks: acks
      }

      :gen_tcp.send(state.socket, Packet.encode(suback))
      {:none}
    end
  end

  def schedule_publish(%Packet.Publish{topic: topic} = publish) do
    fn state ->
      Logger.info("received PUBLISH to #{topic} from client: #{state.client_id}")

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
    fn state ->
      Logger.info("Publishing to client #{state.client_id} with msg: #{message}")
      :gen_tcp.send(state.socket, Packet.encode(publish))
      {:none}
    end
  end

  def log_disconnect() do
    fn state ->
      Logger.info("received DISCONNECT. client id: #{state.client_id}")
      {:none}
    end
  end

  def send_pingresp() do
    fn state ->
      Logger.info("sending PINGRESP. client id: #{state.client_id}")
      :gen_tcp.send(state.socket, Packet.encode(%Packet.Pingresp{}))
      {:none}
    end
  end

  def send_disconnect(error) do
    fn _ ->
      Logger.warn("error reading tcp socket")
      exit(error)
    end
  end

  def close_connection() do
    fn state ->
      Logger.info("connection closed. client_id=#{state.client_id}")
      exit(:shutdown)
    end
  end
end
