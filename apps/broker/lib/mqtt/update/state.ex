defmodule Mqtt.Update.State do
  defstruct socket: nil,
            client_id: nil,
            in_flight_pubs: []
end