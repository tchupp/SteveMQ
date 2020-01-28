defmodule Connection.Inflight do
  @moduledoc false

  use GenStateMachine
  alias Connection.Inflight
  alias Connection.Inflight.Tracked

  @enforce_keys [:client_id]
  defstruct client_id: nil, pending: %{}, order: []

  alias __MODULE__, as: Data

  # Client API
  def start_link(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    GenStateMachine.start_link(__MODULE__, opts, name: via_name(client_id))
  end

  def stop(client_id) do
    GenStateMachine.stop(via_name(client_id))
  end

  def connect(client_id, socket) do
    :ok = GenStateMachine.cast(via_name(client_id), {:connect, socket})
  end

  def disconnect(client_id) do
    :ok = GenStateMachine.cast(via_name(client_id), :disconnect)
  end

  def receive(client_id, %Packet.Puback{} = packet) do
    :ok = GenStateMachine.cast(via_name(client_id), {:receive, packet})
  end

  def track_incoming(client_id, %Packet.Publish{} = publish) do
    :ok = GenStateMachine.cast(via_name(client_id), {:incoming, publish})
  end

  def track_outgoing(client_id, packet) do
    caller = {_, ref} = {self(), make_ref()}

    case packet do
      %Packet.Publish{} ->
        :ok = GenStateMachine.cast(via_name(client_id), {:outgoing, caller, packet})
        {:ok, ref}

      %Packet.Subscribe{} ->
        :ok = GenStateMachine.cast(via_name(client_id), {:outgoing, caller, packet})
        {:ok, ref}
    end
  end

  def track_outgoing_sync(client_id, packet, timeout \\ :infinity) do
    {:ok, ref} = track_outgoing(client_id, packet)

    receive do
      {{Inflight, ^client_id}, ^ref, result} ->
        result
    after
      timeout -> {:error, :timeout}
    end
  end

  defp via_name(client_id) do
    Client.Bucket.via_name(__MODULE__, client_id)
  end

  # Server callbacks
  @impl true
  def init(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    initial_data = %Data{client_id: client_id}

    {:ok, :disconnected, initial_data}
  end

  # when we connect, send pending publishes
  @impl true
  def handle_event(
        :cast,
        {:connect, socket},
        :disconnected,
        %Data{pending: pending, order: order} = data
      ) do
    next_actions =
      for packet_id <- Enum.reverse(order) do
        tracked =
          Map.get(pending, packet_id, :none)
          |> Tracked.publishing_duplicate()

        {:next_event, :internal, {:execute, tracked}}
      end

    {:next_state, {:connected, socket}, data, next_actions}
  end

  # when we disconnect, update state
  def handle_event(
        :cast,
        :disconnect,
        {:connected, _socket},
        %Data{} = data
      ) do
    {:next_state, :disconnected, data}
  end

  # Received QoS 0 - do nothing
  def handle_event(
        :cast,
        {:incoming, %Packet.Publish{qos: 0}},
        {:connected, _socket},
        %Data{} = _data
      ) do
    :keep_state_and_data
  end

  # Received QoS 1 Publish - record and schedule puback
  def handle_event(
        :cast,
        {:incoming, %Packet.Publish{qos: 1, packet_id: packet_id} = publish},
        {:connected, _socket},
        %Data{pending: pending, order: order} = data
      ) do
    tracked = Tracked.new_incoming_publish(publish)

    data = %Data{
      data
      | pending: Map.put_new(pending, packet_id, tracked),
        order: [packet_id | order]
    }

    next_actions = [
      {:next_event, :internal, {:execute, tracked}}
    ]

    {:keep_state, data, next_actions}
  end

  # Sending Publish - no packet_id
  def handle_event(
        :cast,
        {:outgoing, caller, %Packet.Publish{packet_id: nil} = publish},
        _state,
        %Data{pending: pending, order: order} = data
      ) do
    {:ok, publish} = assign_identifier(publish, pending)

    next_actions = [
      {:next_event, :internal, {:outgoing, caller, publish}}
    ]

    {:keep_state, data, next_actions}
  end

  # Sending Publish
  def handle_event(
        _from,
        {:outgoing, caller, %Packet.Publish{packet_id: packet_id} = publish},
        _state,
        %Data{pending: pending, order: order} = data
      ) do
    tracked = Tracked.new_outgoing_publish(caller, publish)

    data = %Data{
      data
      | pending: Map.put_new(pending, packet_id, tracked),
        order: [packet_id | order]
    }

    next_actions = [
      {:next_event, :internal, {:execute, tracked}}
    ]

    {:keep_state, data, next_actions}
  end

  # received puback
  def handle_event(
        :cast,
        {:receive, %Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}} = puback},
        {:connected, socket},
        %Data{pending: pending, order: order} = data
      ) do
    with {:ok, tracked} <- Map.fetch(pending, packet_id),
         {:ok, tracked} <- Tracked.received_puback(tracked, puback) do
      next_actions = [
        {:next_event, :internal, {:execute, tracked}}
      ]

      data = %Data{
        data
        | pending: Map.put(pending, packet_id, tracked),
          order: [packet_id | order -- [packet_id]]
      }

      {:keep_state, data, next_actions}
    end
  end

  # send packet over socket
  def handle_event(
        :internal,
        {:execute, %Tracked{actions: [[{:send, packet}, _] | _]} = tracked},
        {:connected, socket},
        %Data{} = data
      ) do
    :ok = :gen_tcp.send(socket, Packet.encode(packet))
    {:keep_state, handle_next(tracked, data)}
  end

  # send message to pid
  def handle_event(
        :internal,
        {:execute, %Tracked{actions: [[{:respond, {pid, ref}}, _] | _]}},
        {:connected, socket},
        %Data{client_id: client_id} = _data
      ) do
    send(pid, {{Inflight, client_id}, ref, :ok})
    :keep_state_and_data
  end

  def handle_event(
        :internal,
        {:execute, %Tracked{actions: [[{:send, _}, _] | _]}},
        :disconnected,
        %Data{} = _data
      ) do
    :keep_state_and_data
  end

  # helping stuffs
  defp handle_next(
         %Tracked{actions: [[_, :cleanup]], packet_id: packet_id},
         %Data{pending: pending, order: order} = data
       ) do
    order = order -- [packet_id]
    %Data{data | pending: Map.delete(pending, packet_id), order: order}
  end

  defp handle_next(_track, %Data{} = data), do: data

  defp assign_identifier(%Packet.Publish{packet_id: nil} = packet, pending) do
    case :crypto.strong_rand_bytes(2) do
      <<0, 0>> ->
        # an identifier cannot be zero
        assign_identifier(packet, pending)

      <<packet_id::integer-size(16)>> ->
        unless Map.has_key?(pending, packet_id) do
          {:ok, %Packet.Publish{packet | packet_id: packet_id}}
        else
          assign_identifier(packet, pending)
        end
    end
  end
end
