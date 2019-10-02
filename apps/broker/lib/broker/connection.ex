defmodule Broker.Connection do
  use GenServer, restart: :temporary
  require Logger

  # client

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def process_incoming(server, packet) do
    GenServer.call(server, {:process_incoming, packet})
  end

  # server

  @impl true
  def init(socket) do
    server = self()
    Task.start_link(fn -> read_loop(server, socket) end)
    {:ok, {socket}}
  end

  defp read_loop(server, socket) do
    result = :gen_tcp.recv(socket, 0)

    case result do
      {:ok, raw_packet} ->
        :ok = process_incoming(server, raw_packet)
        read_loop(server, socket)

      {:error, :closed} ->
        Logger.info("connection closed. shutting down process")
        exit(:shutdown)
    end
  end

  @impl true
  def handle_call({:process_incoming, raw_packet}, _from, {socket}) do
    parsed_packet = Broker.Packet.parse(raw_packet)
    handle(socket, parsed_packet)
    {:reply, :ok, {socket}}
  end

  defp handle(_, {:error, :closed}) do
    Logger.info("connection close, shutting down")
    exit(:shutdown)
  end

  defp handle(socket, {:connect, data}) do
    Broker.Connection.Registry.register(Broker.Connection.Registry, data[:client_id], self())

    Logger.info("received CONNECT from client id: #{data[:client_id]}, protocol level #{data[:protocol_level]}. Sending CONNACK")

    connack = <<32, 2, 0, 0>>
    :gen_tcp.send(socket, connack)
  end

  defp handle(socket, {:not_implemented_connect, msg}) do
    Logger.info("received CONNECT with unimplemented options: #{msg}")

    #    haven't figured out how to send the right error code, but sending any causes the client to properly disconnect
    impl_specific_error_connack = <<32, 2, 0, 131>>
    :gen_tcp.send(socket, impl_specific_error_connack)
  end

  defp handle(socket, {:subscribe, _}) do
    Logger.info("received SUBSCRIBE, sending SUBACK")

    suback = <<144, 4, 3, 31, ?h, ?i>>
    :gen_tcp.send(socket, suback)
  end

  defp handle(socket, {:publish, _}) do
    Logger.info("received PUBLISH... sending nonsense")

    suback = <<144, 4, 3, 31, ?h, ?i>>
    :gen_tcp.send(socket, suback)
  end

  defp handle(socket, {:error, error}) do
    Logger.info("error reading tcp socket: #{error}")

    unknown_error_connack = <<32, 2, 0, 131>>
    :gen_tcp.send(socket, unknown_error_connack)
    exit(error)
  end
end
