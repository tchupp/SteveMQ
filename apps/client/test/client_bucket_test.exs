defmodule Client.BucketTest do
  use ExUnit.Case
  doctest Client.Bucket

  setup context do
    _ = start_supervised!({Registry, keys: :unique, name: Client.Bucket})
    :ok
  end

  test "via_name/2", context do
    {mod, name} = {__MODULE__, context.test}

    assert {:via, Registry, {Client.Bucket, {^mod, ^name}}} = Client.Bucket.via_name(mod, name)
  end

  test "meta put, get, delete", context do
    key = Client.Bucket.via_name(__MODULE__, context.test)
    value = :crypto.strong_rand_bytes(2)

    assert :error == Client.Bucket.meta(key)
    assert :ok = Client.Bucket.put_meta(key, value)
    assert {:ok, ^value} = Client.Bucket.meta(key)
    assert :ok = Client.Bucket.delete_meta(key)
    assert :error == Client.Bucket.meta(key)
  end
end
