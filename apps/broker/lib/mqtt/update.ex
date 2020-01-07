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
            Broker.Command.register_clientid(client_id, self()),
            case clean_session do
              true -> Broker.Command.start_new_session(client_id)
              false -> Broker.Command.continue_session(client_id)
            end
            <|> (&Broker.Command.send_connack/1)
          ]
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

      {:publish_qos1, %Packet.Publish{qos: 1, packet_id: packet_id} = publish} ->
        {
          put_in(state.in_flight_pubs, state.in_flight_pubs ++ [packet_id]),
          [Broker.Command.schedule_publish(publish)]
        }

      {:disconnect} ->
        {state, [Broker.Command.log_disconnect()]}

      {:connection_closed} ->
        {state, [Broker.Command.close_connection()]}

      {:pingreq, %Packet.Pingreq{}} ->
        {state, [Broker.Command.send_pingresp()]}

      {:unknown, error} ->
        {state, [Broker.Command.send_disconnect(error)]}

      {:error, error} ->
        {state, [Broker.Command.send_disconnect(error)]}

      _ ->
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
