defmodule ClientOptions do
  @opaque subscription :: {String.t(), 0..2}
  @opaque t :: %__MODULE__{
            client_id: String.t(),
            clean_start: boolean(),
            host: List.Chars.t(),
            port: 1024..65535,
            subscriptions: [subscription]
          }

  @enforce_keys [:client_id]
  defstruct client_id: nil, clean_start: true, host: 'localhost', port: 1883, subscriptions: []
end
