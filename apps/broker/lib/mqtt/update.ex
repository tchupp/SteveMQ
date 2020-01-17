defmodule Mqtt.Update do
  require Logger

  @doc """
    update(event, state) -> state, [command]
  """
  def update(event, state) do
    case event do
      {:connect, %Packet.Connect{client_id: client_id, clean_session: clean_session}} ->
        {
          %{state | client_id: client_id},
          [
            Broker.Command.register_client_id(client_id, self()),
            case clean_session do
              true -> Broker.Command.start_new_session(client_id)
              false -> Broker.Command.continue_session(client_id)
            end
          ]
        }

      {:session_retrieved, session_present?: session_present?, session: %Mqtt.Session{} = session} ->
        {
          state,
          [Broker.Command.send_connack(session_present?)] ++
            case session.inbox do
              [] -> []
              [first | _] -> [Broker.Command.deliver_queued_message(first)]
            end
        }

      {:connect_error, error_message} ->
        {
          state,
          [Broker.Command.send_disconnect(error_message)]
        }

      {:subscribe, %Packet.Subscribe{} = packet} ->
        {state, [Broker.Command.add_subscription(packet)]}

      {:subscription_added, %{acks: _acks, packet_id: _packet_id} = data} ->
        {state, [Broker.Command.send_suback(data)]}

      {:publish_qos0, %Packet.Publish{qos: 0} = publish} ->
        {state, [Broker.Command.schedule_publish(publish)]}

      {:publish_qos1, %Packet.Publish{} = publish} ->
        {
          state,
          [Broker.Command.schedule_publish(publish)]
        }

      {:publish_acknowledged, %Packet.Publish{qos: 1, packet_id: packet_id}} ->
        {
          state,
          [Broker.Command.send_puback(packet_id)]
        }

      {:puback, %Packet.Puback{packet_id: packet_id}} ->
        {state, [Broker.Command.mark_delivered(packet_id)]}

      {:no_publish_delivered, pub_id} ->
        {state, [Broker.Command.mark_delivered_by_pub_id(pub_id)]}

      {:queued_messages_found, inbox} ->
        {
          state,
          case inbox do
            [] -> []
            [first | _] -> [Broker.Command.deliver_queued_message(first)]
          end
        }

      {:disconnect, reason} ->
        {state, [Broker.Command.log_disconnect(reason)]}

      {:connection_closed} ->
        {state, [Broker.Command.close_connection()]}

      {:pingreq, %Packet.Pingreq{}} ->
        {state, [Broker.Command.send_pingresp()]}

      {:unknown, error} ->
        {state, [Broker.Command.send_disconnect(error)]}

      {:error, error} ->
        {state, [Broker.Command.send_disconnect(error)]}

      {event_type} ->
        _ = Logger.info("Unhandled event. event_type=#{event_type}")
        {state, []}

      {event_type, _} ->
        _ = Logger.info("Unhandled event. event_type=#{event_type}")
        {state, []}

      _ ->
        _ = Logger.info("Update received malformed event")
        {state, []}
    end
  end

  def left
      <|> right,
      do: compose(left, right)

  defp compose(f, g) when is_function(g) do
    fn arg -> compose(g, f.(arg)).(arg) end
  end

  defp compose(f, arg) do
    f.(arg)
  end
end
