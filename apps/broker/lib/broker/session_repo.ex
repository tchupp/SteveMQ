defmodule Broker.SessionRepo do
  def new_session(client_id, expiry) do
    :ok = :mnesia.dirty_write({Session, client_id, expiry})
  end

  def get_session(client_id) do
    :mnesia.dirty_read({Session, client_id})
  end
end
