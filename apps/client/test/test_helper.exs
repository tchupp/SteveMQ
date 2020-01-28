Code.require_file("./helping_stuff/test_tcp_thing.exs", __DIR__)
{:ok, _} = TestHelper.FakeTCPThing.start_link()

ExUnit.start(capture_log: true)
