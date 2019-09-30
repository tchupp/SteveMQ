defmodule Broker do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(Broker.ConnectionSupervisor, {Broker.Connection, client})

    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end
end
