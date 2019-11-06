defmodule Mqtt.Update do
  require Logger

  # update(event, state) -> state, [command]
  def update(event, state) do
    {socket, _client_id} = state

    case event do
      {:connect, %Packet.Connect{client_id: client_id, clean_session: clean_session} = packet} ->
        {
          {socket, client_id},
          [
            Broker.Command.register_clientid(client_id, self()),
            case clean_session do
              true -> Broker.Command.start_new_session(client_id)
              false -> Broker.Command.continue_session(client_id)
            end
            <|> (&Broker.Command.send_connack/1)
          ]
        }

      {:subscribe, data} ->
        {state, [Broker.Command.add_subscription(data)]}

      {:subscription_added, packet_id} ->
        {state, [Broker.Command.send_suback(packet_id)]}

      {:publish_qos0, publish} ->
        {state, [Broker.Command.schedule_publish(publish)]}

      {:publish_qos1, %Packet.Publish{packet_id: packet_id} = publish} ->
        {
          state,
          [
            Broker.Command.send_puback(packet_id),
            Broker.Command.schedule_publish(publish)
          ]
        }

      {:disconnect} ->
        {state, [Broker.Command.log_disconnect()]}

      {:connection_closed} ->
        {state, [Broker.Command.close_connection()]}

      {:pingreq} ->
        {state, [Broker.Command.send_pingresp()]}

      {:unknown, error} ->
        {state, [Broker.Command.send_disconnect(socket, error)]}

      {:error, error} ->
        {state, [Broker.Command.send_disconnect(socket, error)]}

      _ ->
        {state, []}
    end
  end

  def left <|> right, do: compose(left, right)

  defp compose(f, g) when is_function(g) do
    fn arg -> compose(g, f.(arg)).(arg) end
  end

  defp compose(f, arg) do
    f.(arg)
  end
end
