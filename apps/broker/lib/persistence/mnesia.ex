defmodule Persistence.Mnesia do
  def init() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(Session, disc_copies: [node()], attributes: [:client_id, :expiry])
    :mnesia.create_table(Subscription, attributes: [:client_id, :topic_filter, :pid])
    :mnesia.add_table_index(Subscription, :topic_filter)
  end
end
