defmodule Broker do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} = Task.Supervisor.start_child(Broker.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(socket) do
    {:ok, raw_packet} = read_line(socket)

    parsed_msg = Broker.Packet.parse(raw_packet)

    write_line(socket, parsed_msg)
    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, {:connect, data}) do
    Logger.info("received CONNECT from client id: #{data[:client_id]}")

    connack = <<32, 2, 0, 0>>
    :gen_tcp.send(socket, connack)
  end

  defp write_line(socket, {:not_implemented_connect, msg}) do
    Logger.info("received CONNECT with unimplemented options: #{msg}")

    #    haven't figured out how to send the right error code, but sending any causes the client to properly disconnect
    impl_specific_error_connack = <<32, 2, 0, 131>>
    :gen_tcp.send(socket, impl_specific_error_connack)
  end

  defp write_line(socket, {:subscribe, data}) do
    Logger.info("received SUBSCRIBE")

    suback = <<144, 1, 0>>
    :gen_tcp.send(socket, suback)
  end

  defp write_line(socket, {:error, error}) do
    Logger.info("error processing CONNECT: #{error}")
    unknown_error_connack = <<32, 2, 0, 131>>

    :gen_tcp.send(socket, unknown_error_connack)
    exit(error)
  end
end
