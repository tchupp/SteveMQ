defmodule Mqtt.Update do
  require Logger
  # update(event, state) -> state, [command]

  def x <|> y, do: compose(y, x)

  def compose(f, g) when is_function(g) do
    fn arg -> compose(f, g.(arg)).(arg) end
  end

  def compose(f, arg) do
    f.(arg)
  end

  def update(event, state) do
    {socket, client_id} = state

    case event do
      {:connect, data} ->
        client_id = data[:client_id]
        {
          {socket, data[:client_id]},
          [
            Broker.Command.register_clientid(client_id, self()),
            case data[:clean_session] do
              true -> Broker.Command.start_new_session(client_id)
              false -> Broker.Command.continue_session(client_id)
            end
          ]
        }

      {:session_started, session_present?} ->
        {state, [Broker.Command.send_connack(session_present?)]}

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
