defmodule Broker.Application do
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "1883")

    children = [
      {DynamicSupervisor, name: Broker.ConnectionSupervisor, strategy: :one_for_one},
      Supervisor.child_spec({Task, fn -> Broker.accept(port) end}, restart: :temporary)
    ]

    opts = [strategy: :one_for_one, name: Broker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
