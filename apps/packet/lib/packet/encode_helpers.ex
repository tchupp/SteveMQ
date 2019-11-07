defmodule Packet.Encode2 do
  use Bitwise

  def variable_length_prefixed(bytes) do
    length_prefix =
      byte_size(bytes)
      |> variable_length_int()

    length_prefix <> bytes
  end

  @highbit 0b10000000
  def variable_length_int(n) when n < @highbit, do: <<0::1, n::7>>

  def variable_length_int(n) do
    <<1::1, rem(n, @highbit)::7>> <> variable_length_int(div(n, @highbit))
  end

  def fixed_length_prefixed(data) do
    <<byte_size(data)::16, data::binary>>
  end
end
