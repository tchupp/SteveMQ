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
      session = Mqtt.Session.new_session(client_id)
      {:session_retrieved, session_present?: false, session: session}
    end
  end

  def continue_session(client_id) do
    fn _ ->
      Logger.debug("Continuing session for #{client_id}")
      {session, session_present?: session_present?} = Mqtt.Session.continue_session(client_id)
      {:session_retrieved, session_present?: session_present?, session: session}
    end
  end

  def send_connack(session_present?) do
    fn state ->
      Logger.info("Sending CONNACK, session present: #{session_present?}")

      :gen_tcp.send(
        state.socket,
        Packet.encode(%Connack{session_present?: session_present?, status: :accepted})
      )

      {:none}
    end
  end

  def schedule_puback(packet_id) do
    fn state ->

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

  def deliver_queued_message({pub_id, _}) do
    Logger.debug("delivering Qd message")

    fn state ->
      case Mqtt.QueuedMessage.get_payload(pub_id) do
        nil -> {:no_publish_delivered}
        publish -> publish_to_client(publish).(state)
      end
    end
  end

  def add_subscription(%Packet.Subscribe{topics: topics, packet_id: packet_id}) do
    fn state ->
      for {topic_filter, qos} <- topics do
        Logger.info(
          "received SUBSCRIBE. client_id=#{state.client_id} topic_filter=#{topic_filter} qos=#{
            qos
          }"
        )

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

  def schedule_publish(%Packet.Publish{topic: topic, qos: qos, packet_id: packet_id} = publish) do
    fn state ->
      Logger.info("received PUBLISH to #{topic} from client: #{state.client_id}")

      subscribers = Mqtt.Subscription.get_subscribers(topic)
      pub_id = make_ref()

      for subscriber <- subscribers do
        case subscriber do
          {:online, client_id, pid} ->
            Broker.Connection.schedule_cmd_external(pid, publish_to_client(publish))

          {:offline, client_id} ->
            Mqtt.QueuedMessage.store_payload(pub_id, publish, client_id)

            Mqtt.Session.queue_message(client_id,
              pub_id: pub_id,
              packet_id: packet_id,
              topic: topic,
              qos: qos
            )
        end
      end

      {:publish_acknowledged, publish}
    end
  end

  def publish_to_client(%Packet.Publish{message: message} = publish) do
    fn state ->
      Logger.debug("Publishing to client #{state.client_id} with msg: #{message}")
      :gen_tcp.send(state.socket, Packet.encode(publish))
      {:none}
    end
  end

  def mark_delivered(packet_id) do
    fn state ->
      Logger.debug("Received puback with packet_id #{packet_id} from #{state.client_id}")

      Mqtt.Session.mark_delivered(state.client_id, packet_id)
      {:none}
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
