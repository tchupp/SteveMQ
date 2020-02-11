defmodule Connection.Receiver do
  @moduledoc false

  use GenStateMachine

  defstruct client_id: nil, socket: nil, buffer: <<>>
  alias __MODULE__, as: Data

  # Client API
  def start_link(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    GenStateMachine.start_link(__MODULE__, opts, name: via_name(client_id))
  end

  def stop(client_id) do
    GenStateMachine.stop(via_name(client_id))
  end

  def handle_socket(client_id, socket) do
    {:ok, pid} = GenStateMachine.call(via_name(client_id), {:handle_socket, socket})

    case :gen_tcp.controlling_process(socket, pid) do
      :ok ->
        :ok

      {:error, reason} when reason in [:closed, :einval] ->
        # todo, this is an edge case, figure out what to do here
        :ok
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

  # set us up the socket
  @impl true
  def handle_event({:call, from}, {:handle_socket, socket}, :disconnected, data) do
    new_state = {:connected, :receiving_fixed_header}

    next_actions = [
      {:reply, from, {:ok, self()}},
      {:next_event, :internal, :activate_socket},
      {:next_event, :internal, :consume_buffer}
    ]

    # just gotta reset the buffer
    new_data = %Data{data | socket: socket, buffer: <<>>}

    {:next_state, new_state, new_data, next_actions}
  end

  # receiving data on the network connection
  @impl true
  def handle_event(:info, {transport, _socket, tcp_data}, _, %Data{} = data)
      when transport in [:tcp] do
    next_actions = [
      {:next_event, :internal, :activate_socket},
      {:next_event, :internal, :consume_buffer}
    ]

    new_data = %Data{data | buffer: <<data.buffer::binary, tcp_data::binary>>}
    {:keep_state, new_data, next_actions}
  end

  def handle_event(
        :internal,
        :activate_socket,
        _state,
        %Data{socket: socket} = data
      ) do
    case :inet.setopts(socket, active: :once) do
      :ok ->
        :keep_state_and_data

      {:error, :einval} ->
        # TODO: what do with buffer?
        {:next_state, :disconnected, data}
    end
  end

  # we are receiving the fixed length header
  def handle_event(
        :internal,
        :consume_buffer,
        {:connected, :receiving_fixed_header},
        %Data{} = data
      ) do
    case parse_fixed_header(data.buffer) do
      {:ok, length} ->
        new_state = {:connected, {:receiving_variable_header, length}}
        next_actions = [{:next_event, :internal, :consume_buffer}]
        {:next_state, new_state, data, next_actions}

      :need_more_bytes ->
        :keep_state_and_data

      {:error, :invalid_header_length} ->
        {:stop, {:protocol_violation, :invalid_header_length}}
    end
  end

  # we are receiving the variable length header
  def handle_event(
        :internal,
        :consume_buffer,
        {:connected, {:receiving_variable_header, length}},
        %Data{buffer: buffer} = data
      ) do
    cond do
      byte_size(buffer) >= length ->
        <<packet::binary-size(length), rest::binary>> = buffer
        next_state = {:connected, :receiving_fixed_header}

        next_actions = [
          {:next_event, :internal, {:emit, packet}},
          {:next_event, :internal, :consume_buffer}
        ]

        new_data = %{data | buffer: rest}
        {:next_state, next_state, new_data, next_actions}

      true ->
        # await more bytes
        :keep_state_and_data
    end
  end

  def handle_event(:internal, {:emit, packet}, _, %Data{client_id: client_id} = _data) do
    packet = Packet.decode(packet)
    :ok = Client.receive_packet(client_id, packet)
    :keep_state_and_data
  end

  defp parse_fixed_header(<<_::8, 0::1, length::7, _::binary>>) do
    {:ok, length + 2}
  end

  # 2 bytes
  defp parse_fixed_header(<<_::8, 1::1, a::7, 0::1, b::7, _::binary>>) do
    <<length::integer-size(14)>> = <<b::7, a::7>>
    {:ok, length + 3}
  end

  # 3 bytes
  defp parse_fixed_header(<<_::8, 1::1, a::7, 1::1, b::7, 0::1, c::7, _::binary>>) do
    <<length::integer-size(21)>> = <<c::7, b::7, a::7>>
    {:ok, length + 4}
  end

  # 4 bytes
  defp parse_fixed_header(<<_::8, 1::1, a::7, 1::1, b::7, 1::1, c::7, 0::1, d::7, _::binary>>) do
    <<length::integer-size(28)>> = <<d::7, c::7, b::7, a::7>>
    {:ok, length + 5}
  end

  defp parse_fixed_header(header) when byte_size(header) > 5 do
    {:error, :invalid_header_length}
  end

  defp parse_fixed_header(_) do
    :need_more_bytes
  end
end
