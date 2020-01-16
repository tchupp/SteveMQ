defmodule Broker.Command do
  require Logger

  alias Packet.Connack

  @doc """
    - Return {:none} from commands to report no events
    - Otherwise, Events look like this: {<event type atom>, <optional: more stuff>}

    - Commands return closures with arity:1, which accept connection state
  """

  def register_client_id(client_id, pid) do
    fn _ ->
      Logger.debug("Registering client. client_id=#{client_id}")
      Broker.Connection.Registry.register(Broker.Connection.Registry, client_id, pid)
      {:none}
    end
  end

  def start_new_session(client_id) do
    fn _ ->
      Logger.debug("Starting new session. client_id=#{client_id}")
      session = Mqtt.Session.new_session(client_id)
      {:session_retrieved, session_present?: false, session: session}
    end
  end

  def continue_session(client_id) do
    fn _ ->
      {session, session_present?: session_present?} = Mqtt.Session.continue_session(client_id)
      Logger.debug("Continuing session.\
               client_id=#{client_id} pending_publishes=#{length(session.inbox)}")

      {:session_retrieved, session_present?: session_present?, session: session}
    end
  end

  def send_connack(session_present?) do
    fn state ->
      Logger.info(
        "Sending CONNACK. client_id=#{state.client_id} session_present=#{session_present?}"
      )

      :gen_tcp.send(
        state.socket,
        Packet.encode(%Connack{session_present?: session_present?, status: :accepted})
      )

      {:none}
    end
  end

  def send_puback(packet_id) do
    fn state ->
      Logger.info("Sending PUBACK. client_id=#{state.client_id} packet_id=#{packet_id}")

      :gen_tcp.send(
        state.socket,
        Packet.encode(%Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}})
      )

      {:none}
    end
  end

  def deliver_queued_message({pub_id, _}) do
    fn state ->
      Logger.debug("Delivering queued message. client_id=#{state.client_id}")

      case Mqtt.QueuedMessage.get_payload(pub_id) do
        nil -> {:no_publish_delivered, pub_id}
        publish -> publish_to_client(publish).(state)
      end
    end
  end

  def add_subscription(%Packet.Subscribe{topics: topics, packet_id: packet_id}) do
    fn state ->
      for {topic_filter, qos} <- topics do
        Logger.info("received SUBSCRIBE.\
                       client_id=#{state.client_id} topic_filter=#{topic_filter} qos=#{qos}")

        Mqtt.Subscription.add_subscription(state.client_id, topic_filter, self())
      end

      {
        :subscription_added,
        %{
          acks:
            topics
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

  def schedule_publish(%Packet.Publish{qos: 0, packet_id: nil, topic: topic} = publish) do
    fn _state ->
      for subscriber <- Mqtt.Subscription.get_subscribers(topic) do
        case subscriber do
          {:online, _client_id, pid} ->
            Broker.Connection.schedule_cmd_external(pid, publish_to_client(publish))
        end
      end

      {:publish_scheduled, publish}
    end
  end

  def schedule_publish(%Packet.Publish{qos: 1, packet_id: packet_id, topic: topic} = publish) do
    fn state ->
      Logger.info("Received PUBLISH. topic=#{topic} client_id=#{state.client_id}")
      pub_id = make_ref()

      for subscriber <- Mqtt.Subscription.get_subscribers(topic) do
        case subscriber do
          {:online, _client_id, pid} ->
            Broker.Connection.schedule_cmd_external(pid, publish_to_client(publish))

          {:offline, client_id} ->
            :ok = Mqtt.QueuedMessage.store_payload(pub_id, publish, client_id)

            :ok =
              Mqtt.Session.queue_message(client_id,
                pub_id: pub_id,
                packet_id: packet_id,
                topic: topic,
                qos: 1
              )
        end
      end

      {:publish_acknowledged, publish}
    end
  end

  def publish_to_client(%Packet.Publish{qos: qos, packet_id: packet_id} = publish) do
    fn state ->
      Logger.debug("Publishing to client.\
              client_id=#{state.client_id} packet_id=#{packet_id} qos=#{qos}")
      :gen_tcp.send(state.socket, Packet.encode(publish))
      {:none}
    end
  end

  def mark_delivered(packet_id) do
    fn %Mqtt.Update.State{client_id: client_id} ->
      Logger.debug("Received PUBACK. client_id=#{client_id} packet_id=#{packet_id}")

      {:ok, pub_id} = Mqtt.Session.mark_delivered(client_id, packet_id)
      :ok = Mqtt.QueuedMessage.mark_delivered(client_id, pub_id)

      inbox = Mqtt.Session.get_queued_messages(client_id)
      {:queued_messages_found, inbox}
    end
  end

  def mark_delivered_by_pub_id(pub_id) do
    fn state ->
      Logger.debug("Payload not found. client_id=#{state.client_id}")

      {:ok, pub_id} = Mqtt.Session.mark_delivered_by_pub_id(state.client_id, pub_id)
      :ok = Mqtt.QueuedMessage.mark_delivered(state.client_id, pub_id)

      inbox = Mqtt.Session.get_queued_messages(state.client_id)
      {:queued_messages_found, inbox}
    end
  end

  def log_disconnect(reason) do
    fn state ->
      Logger.info("received DISCONNECT. client id: #{state.client_id}, reason: #{reason}")
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
