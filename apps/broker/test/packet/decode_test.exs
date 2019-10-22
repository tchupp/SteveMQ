defmodule Packet.DecodeTest do
  use ExUnit.Case, async: true

  describe "CONNECT" do
    test "parses CONNECT" do
      protocol_level = 5

      will_retain = false
      will_qos = 1
      will_present = true
      clean_session = true
      keep_alive = 60

      client_id = "hello world"

      will_topic = "if you will it"
      will_payload = "it is no dream"

      username = "joe dirt"
      password = "paul rudd"

      packet_length =
        6 + # protocol size
        1 + # protocol level size
        1 + # connect flags size
        2 + # keep alive size
        1 + # properties size
        2 + String.length(client_id) +
        2 + String.length(will_topic) +
        2 + String.length(will_payload) +
        2 + String.length(username) +
        2 + String.length(password)

      connect =
        # fixed header - packet type
        <<1 :: 4, 0 :: 4>> <>
        # fixed header - remaining length
        <<packet_length>> <>
        # variable header - protocol
        <<4::16, "MQTT">> <>
        # variable header - protocol level
        <<5>> <>
        # variable header - connect flags
        <<
          flag(username) :: 1,
          flag(password) :: 1,
          flag(will_retain) :: 1,
          will_qos :: 2,
          flag(will_present) :: 1,
          flag(clean_session) :: 1,
          0 :: 1
        >> <>
        # variable header - connect flags - keep alive
        <<keep_alive :: 16>> <>
        # variable header - properties - length and data
        <<0>> <>
        # payload - client id - length and data
        <<String.length(client_id)::16, client_id :: binary>> <>
        # payload - will topic - length and data
        <<String.length(will_topic)::16, will_topic :: binary>> <>
        # payload - will payload - length and data
        <<String.length(will_payload)::16, will_payload :: binary>> <>
        # payload - username - length and data
        <<String.length(username)::16, username :: binary>> <>
        # payload - password - length and data
        <<String.length(password)::16, password :: binary>>

      assert Packet.Decode.decode(connect) == {
               :connect,
               %{
                 client_id: client_id,
                 username: username,
                 password: password,
                 clean_session: clean_session,
                 keep_alive: keep_alive,
                 protocol_level: protocol_level,
                 will: %{
                   qos: 1,
                   topic: will_topic,
                   payload: will_payload,
                   retain: false,
                 },
               }
             }
    end

    test "returns :unknown if protocol is not 'MQTT'" do
      connect =
        # fixed header - packet type
        <<1 :: 4, 0 :: 4>> <>
        # fixed header - remaining length
        <<24>> <>
        # variable header - protocol
        <<4 :: 16, "ABCD">> <>
        # variable header - protocol level
        <<5>> <>
        # variable header - connect flags
        <<2::8>> <>
        # variable header - connect flags - keep alive
        <<60::16>> <>
        # variable header - properties - length and data
        <<0, 0>> <>
        # payload - client id - length and data
        <<11, "hello world">>

      {type, _error} = Packet.Decode.decode(connect)
      assert type == :unknown
    end
  end

  describe "CONNACK" do
  end

  describe "PUBLISH" do
    test "parses PUBLISH" do
      publish =
        # fixed header - packet type, flags
        <<3 :: 4, 0 :: 1, 0 :: 2, 0 :: 1>> <>
        # fixed header - remaining length
        <<15>> <>
        # variable header - topic - length and data
        <<5 :: 16, "topic">> <>
        <<0>> <>
        <<"message">>

      assert Packet.Decode.decode(publish) == {
               :publish_qos0,
               %{
                 topic: "topic",
                 message: "message",
                 retain: false
               }
             }
    end

    test "parses PUBLISH with extra chars" do
      publish =
        # fixed header - packet type, flags
        <<3 :: 4, 0 :: 1, 0 :: 2, 0 :: 1>> <>
        # fixed header - remaining length
        <<15>> <>
        # variable header - topic - length and data
        <<5 :: 16, "topic">> <>
        # payload - properties - length and data
        <<0>> <>
        # payload - message body
        <<"message?!?">>

      assert Packet.Decode.decode(publish) == {
               :publish_qos0,
               %{
                 topic: "topic",
                 message: "message",
                 retain: false
               }
             }
    end

    test "parses PUBLISH - retain as true - qos 1" do
      publish =
        # fixed header - packet type, flags
        <<3 :: 4, flag(false) :: 1, 1 :: 2, flag(true) :: 1>> <>
        # fixed header - remaining length
        <<17>> <>
        # variable header - topic - length and data
        <<5 :: 16, "topic">> <>
        # variable header - packet id
        <<17 :: 16>> <>
        # payload - properties - length and data
        <<0>> <>
        # payload - message body
        <<"message">>

      assert Packet.Decode.decode(publish) == {
               :publish_qos1,
               %{
                 topic: "topic",
                 message: "message",
                 packet_id: 17,
                 dup: false,
                 retain: true
               }
             }
    end

    test "parses PUBLISH - retain as true - qos 2" do
      publish =
        # fixed header - packet type, flags
        <<3 :: 4, flag(true) :: 1, 2 :: 2, flag(true) :: 1>> <>
        # fixed header - remaining length
        <<17>> <>
        # variable header - topic - length and data
        <<5 :: 16, "topic">> <>
        # variable header - packet id
        <<4 :: 16>> <>
        # payload - properties - length and data
        <<0>> <>
        # payload - message body
        <<"message">>

      assert Packet.Decode.decode(publish) == {
               :publish_qos2,
               %{
                 topic: "topic",
                 message: "message",
                 packet_id: 4,
                 dup: true,
                 retain: true
               }
             }
    end
  end

  describe "PUBACK" do
  end

  describe "PUBREC" do
  end

  describe "PUBREL" do
  end

  describe "PUBCOMP" do
  end

  describe "SUBSCRIBE" do
    test "parses SUBSCRIBE" do
      packet_id = 123

      subscribe =
        <<8::4, 2::4>> <>
          <<14, packet_id::16, 0, 0, 9>> <>
          <<?t, ?e, ?s, ?t, ?T, ?o, ?p, ?i, ?c, 0>>

      {type, packet} = Packet.Decode.decode(subscribe)

      assert type == :subscribe
      assert packet[:topic_filter] == "testTopic"
      assert packet[:packet_id] == packet_id
    end
  end

  describe "SUBACK" do
  end

  describe "UNSUBSCRIBE" do
  end

  describe "UNSUBACK" do
  end

  describe "PINGREQ" do
  end

  describe "PINGRES" do
  end

  describe "DISCONNECT" do
  end

  describe "ERROR" do
    test "returns error for unrecognized message types" do
      {type, _} = Packet.Decode.decode(<<0, 2, 0, 0>>)
      assert type == :unknown
    end
  end

  test "can parse one length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<0, 0>>) == {0, 1, <<0>>}
    assert Packet.Decode.parse_variable_int(<<127, 0>>) == {127, 1, <<0>>}
  end

  test "can parse two length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 1, 0>>) == {128, 2, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 127, 0>>) == {16_383, 2, <<0>>}
  end

  test "can parse three length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 128, 1, 0>>) == {16_384, 3, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 255, 127, 0>>) == {2_097_151, 3, <<0>>}
  end

  test "can parse four length variable length ints" do
    assert Packet.Decode.parse_variable_int(<<128, 128, 128, 1, 0>>) == {2_097_152, 4, <<0>>}
    assert Packet.Decode.parse_variable_int(<<255, 255, 255, 127, 0>>) == {268_435_455, 4, <<0>>}
  end

  test "max variable length bytes is 4" do
    assert_raise RuntimeError, ~r/error/, fn ->
      Packet.Decode.parse_variable_int(<<255, 255, 255, 255, 7>>)
    end
  end

  defp flag(f) when f in [0, nil, false], do: 0
  defp flag(_), do: 1
end
