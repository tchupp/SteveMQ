defmodule Connection.Inflight.Tracked do
  @moduledoc false

  alias Connection.Inflight.Tracked

  @enforce_keys [:direction, :type, :packet_id, :actions]
  defstruct direction: nil,
            type: nil,
            packet_id: nil,
            actions: []

  def new_incoming_publish(%Packet.Publish{qos: 1, packet_id: packet_id} = publish) do
    %Tracked{
      direction: :incoming,
      type: Packet.Publish,
      packet_id: packet_id,
      actions: [
        [
          {:send, %Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}}},
          :cleanup
        ]
      ]
    }
  end

  def new_outgoing({pid, ref}, %Packet.Publish{qos: 0, packet_id: packet_id} = publish)
      when is_pid(pid) and is_reference(ref) do
    %Tracked{
      direction: :outgoing,
      type: Packet.Publish,
      packet_id: packet_id,
      actions: [
        [
          {:send, publish},
          :cleanup
        ]
      ]
    }
  end

  def new_outgoing({pid, ref}, %Packet.Publish{qos: 1, packet_id: packet_id} = publish)
      when is_pid(pid) and is_reference(ref) do
    %Tracked{
      direction: :outgoing,
      type: Packet.Publish,
      packet_id: packet_id,
      actions: [
        [
          {:send, publish},
          {:received, %Packet.Puback{packet_id: packet_id, status: {:accepted, :ok}}}
        ],
        [
          {:respond, {pid, ref}},
          :cleanup
        ]
      ]
    }
  end

  def new_outgoing({pid, ref}, %Packet.Subscribe{packet_id: packet_id} = subscribe)
      when is_pid(pid) and is_reference(ref) do
    %Tracked{
      direction: :outgoing,
      type: Packet.Publish,
      packet_id: packet_id,
      actions: [
        [
          {:send, subscribe},
          {:received, %Packet.Suback{packet_id: packet_id}}
        ],
        [
          {:respond, {pid, ref}},
          :cleanup
        ]
      ]
    }
  end

  def publishing_duplicate(%Tracked{} = tracked) do
    case tracked do
      %Tracked{actions: [[{:send, %Packet.Publish{} = publish} | action] | actions]} = tracked ->
        publish = %Packet.Publish{publish | dup: true}
        tracked = %Tracked{tracked | actions: [[{:send, publish} | action] | actions]}
        tracked

      %Tracked{} = tracked ->
        tracked
    end
  end

  def receive(
        %Tracked{
          actions: [
            [{:send, _outgoing_packet}, {:received, %{__struct__: t, packet_id: packet_id}}]
            | remaining_actions
          ]
        } = tracked,
        %{__struct__: t, packet_id: packet_id} = _received_packet
      ) do
    {:ok, %Tracked{tracked | actions: remaining_actions}}
  end
end
