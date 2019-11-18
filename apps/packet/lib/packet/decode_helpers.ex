defmodule Packet.Decode do
  use Bitwise

  def variable_length_prefixed(<<0::1, l1::7, data::binary>>) do
    variable_int = l1

    {variable_int, 1, data}
  end

  def variable_length_prefixed(<<1::1, l1::7, 0::1, l2::7, data::binary>>) do
    variable_int = l1 + (l2 <<< 7)

    {variable_int, 2, data}
  end

  def variable_length_prefixed(<<1::1, l1::7, 1::1, l2::7, 0::1, l3::7, data::binary>>) do
    variable_int = l1 + (l2 <<< 7) + (l3 <<< 14)

    {variable_int, 3, data}
  end

  def variable_length_prefixed(
        <<1::1, l1::7, 1::1, l2::7, 1::1, l3::7, 0::1, l4::7, data::binary>>
      ) do
    variable_int = l1 + (l2 <<< 7) + (l3 <<< 14) + (l4 <<< 21)

    {variable_int, 4, data}
  end

  def variable_length_prefixed(bytes) do
    raise "error decoding variable length int. more than 4 bytes"
  end

  def fixed_length_prefixed(<<>>), do: []

  def fixed_length_prefixed(<<length::16, payload::binary>>) do
    <<item::binary-size(length), rest::binary>> = payload
    [item] ++ fixed_length_prefixed(rest)
  end
end
