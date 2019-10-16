defmodule Persistence.Mnesia do

  def init() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(Session, [attributes: [:client_id, :expiry]])
  end

end
