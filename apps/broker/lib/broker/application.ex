defmodule Broker.Application do
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "1883")

    children = [
      {Broker.Connection.Supervisor, name: Broker.Connection.Supervisor},
      Supervisor.child_spec({Task, fn -> Broker.accept(port) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: Broker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
