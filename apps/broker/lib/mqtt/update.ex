defmodule Mqtt.Update do
  # update(event, state) -> state, [command]
  def update(event, state) do
    {socket, client_id} = state

    case event do
      {:connect, data} ->
        {
          {socket, data[:client_id]},
          [
            Broker.Command.register_clientid(data[:client_id], self()),
            Broker.Command.send_connack()
          ]
        }

      {:subscribe, data} ->
        {state, [Broker.Command.add_subscription(data)]}

      {:subscription_added, packet_id} ->
        {state, [Broker.Command.send_suback(packet_id)]}

      {:publish_qos0, data} ->
        {state, [Broker.Command.schedule_publish(data)]}

      {:publish_qos1, data} ->
        {
          state,
          [
            Broker.Command.send_puback(data[:packet_id]),
            Broker.Command.schedule_publish(data)
          ]
        }

      {:disconnect} ->
        {state, [Broker.Command.log_disconnect()]}

      {:connection_closed} ->
        {state, [Broker.Command.close_connection()]}

      {:pingreq} ->
        {state, [Broker.Command.send_pingresp()]}

      {:unknown, error} ->
        {state, [Broker.Command.disconnect(socket, error)]}

      {:error, error} ->
        {state, [Broker.Command.disconnect(socket, error)]}

      _ ->
        {state, []}
    end
  end
end
