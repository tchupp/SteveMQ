defmodule Persistence.Mnesia do
  def init() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(Session, attributes: [:client_id, :inbox])

    :mnesia.create_table(Subscription, attributes: [:client_id, :topic_filter, :pid])
    :mnesia.add_table_index(Subscription, :topic_filter)

    :mnesia.create_table(PublishPayload, attributes: [:id, :payload, :ref_count])
  end

  def clear_db() do
    :mnesia.clear_table(Subscription)
    :mnesia.clear_table(Session)
    :mnesia.clear_table(PublishPayload)

    :ok
  end
end
