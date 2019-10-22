defmodule Persistence.Mnesia do

  def init() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(Session, [disc_copies: [node()], attributes: [:client_id, :expiry]])
  end

end
