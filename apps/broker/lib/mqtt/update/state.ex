defmodule Mqtt.Update.State do
  defstruct socket: nil,
            client_id: nil,
            not_ackd_pubs: []
end
