defmodule Broker.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "1883")

    children = [
      {Task.Supervisor, name: Broker.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Broker.accept(port) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: Broker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
