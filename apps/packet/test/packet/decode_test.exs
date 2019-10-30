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
      will_message = "it is no dream"

      username = "joe dirt"
      password = "paul rudd"

      # protocol size
      # protocol level size
      # connect flags size
      # keep alive size
      # properties size
      packet_length =
        6 +
          1 +
          1 +
          2 +
          1 +
          2 + String.length(client_id) +
          2 + String.length(will_topic) +
          2 + String.length(will_message) +
          2 + String.length(username) +
          2 + String.length(password)

      # fixed header - packet type
      # fixed header - remaining length
      # variable header - protocol
      # variable header - protocol level
      # variable header - connect flags
      # variable header - connect flags - keep alive
      # variable header - properties - length and data
      # payload - client id - length and data
      # payload - will topic - length and data
      # payload - will payload - length and data
      # payload - username - length and data
      # payload - password - length and data
      connect =
        <<1::4, 0::4>> <>
          <<packet_length>> <>
          <<4::16, "MQTT">> <>
          <<5>> <>
          <<
            flag(username)::1,
            flag(password)::1,
            flag(will_retain)::1,
            will_qos::2,
            flag(will_present)::1,
            flag(clean_session)::1,
            0::1
          >> <>
          <<keep_alive::16>> <>
          <<0>> <>
          <<String.length(client_id)::16, client_id::binary>> <>
          <<String.length(will_topic)::16, will_topic::binary>> <>
          <<String.length(will_message)::16, will_message::binary>> <>
          <<String.length(username)::16, username::binary>> <>
          <<String.length(password)::16, password::binary>>

      assert Packet.decode(connect) == {
               :connect,
               %Packet.Connect{
                 client_id: client_id,
                 username: username,
                 password: password,
                 clean_session: clean_session,
                 keep_alive: keep_alive,
                 protocol_level: protocol_level,
                 will: %Packet.Publish{
                   qos: 1,
                   topic: will_topic,
                   message: will_message,
                   retain: false
                 }
               }
             }
    end

    test "returns :unknown if protocol is not 'MQTT'" do
      # fixed header - packet type
      # fixed header - remaining length
      # variable header - protocol
      # variable header - protocol level
      # variable header - connect flags
      # variable header - connect flags - keep alive
      # variable header - properties - length and data
      # payload - client id - length and data
      connect =
        <<1::4, 0::4>> <>
          <<24>> <>
          <<4::16, "ABCD">> <>
          <<5>> <>
          <<2::8>> <>
          <<60::16>> <>
          <<0, 0>> <>
          <<11, "hello world">>

      {type, _error} = Packet.decode(connect)
      assert type == :unknown
    end
  end

  describe "CONNACK" do
    test "decodes CONNACK - session_present (true, false)" do
      return_code = 0x00

      # session present size
      # return code size
      packet_length = 2

      connack =
        <<2::4, 0::4>> <>
          <<packet_length::8>> <>
          <<0::7, flag(false)::1>> <>
          <<return_code::8>>

      assert Packet.decode(connack) == {
               :connack,
               %Packet.Connack{
                 session_present?: false,
                 status: :accepted
               }
             }

      connack =
        <<2::4, 0::4>> <>
          <<packet_length::8>> <>
          <<0::7, flag(true)::1>> <>
          <<return_code::8>>

      assert Packet.decode(connack) == {
               :connack,
               %Packet.Connack{
                 session_present?: true,
                 status: :accepted
               }
             }
    end

    test "decodes CONNACK - all status" do
      return_codes = [
        {0x00, :accepted},
        {0x01, {:refused, :unacceptable_protocol_version}},
        {0x02, {:refused, :identifier_rejected}},
        {0x03, {:refused, :server_unavailable}},
        {0x04, {:refused, :bad_user_name_or_password}},
        {0x05, {:refused, :not_authorized}},
        {0x06, nil},
        {0x10, nil},
        {0x18, nil}
      ]

      for {return_code, status} <- return_codes do
        # session present size
        # return code size
        packet_length = 2

        connack =
          <<2::4, 0::4>> <>
            <<packet_length::8>> <>
            <<0::7, flag(false)::1>> <>
            <<return_code::8>>

        assert Packet.decode(connack) == {
                 :connack,
                 %Packet.Connack{
                   session_present?: false,
                   status: status
                 }
               }
      end
    end
  end

  describe "PUBLISH" do
    test "parses PUBLISH" do
      # fixed header - packet type, flags
      # fixed header - remaining length
      # variable header - topic - length and data
      publish =
        <<3::4, 0::1, 0::2, 0::1>> <>
          <<15>> <>
          <<5::16, "topic">> <>
          <<0>> <>
          <<"message">>

      assert Packet.decode(publish) == {
               :publish_qos0,
               %{
                 topic: "topic",
                 message: "message",
                 retain: false
               }
             }
    end

    test "parses PUBLISH with extra chars" do
      # fixed header - packet type, flags
      # fixed header - remaining length
      # variable header - topic - length and data
      # payload - properties - length and data
      # payload - message body
      publish =
        <<3::4, 0::1, 0::2, 0::1>> <>
          <<15>> <>
          <<5::16, "topic">> <>
          <<0>> <>
          <<"message?!?">>

      assert Packet.decode(publish) == {
               :publish_qos0,
               %{
                 topic: "topic",
                 message: "message",
                 retain: false
               }
             }
    end

    test "parses PUBLISH - retain as true - qos 1" do
      # fixed header - packet type, flags
      # fixed header - remaining length
      # variable header - topic - length and data
      # variable header - packet id
      # payload - properties - length and data
      # payload - message body
      publish =
        <<3::4, flag(false)::1, 1::2, flag(true)::1>> <>
          <<17>> <>
          <<5::16, "topic">> <>
          <<17::16>> <>
          <<0>> <>
          <<"message">>

      assert Packet.decode(publish) == {
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
      # fixed header - packet type, flags
      # fixed header - remaining length
      # variable header - topic - length and data
      # variable header - packet id
      # payload - properties - length and data
      # payload - message body
      publish =
        <<3::4, flag(true)::1, 2::2, flag(true)::1>> <>
          <<17>> <>
          <<5::16, "topic">> <>
          <<4::16>> <>
          <<0>> <>
          <<"message">>

      assert Packet.decode(publish) == {
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

    test "fails to parse PUBLISH - qos 3" do
      # fixed header - packet type, flags
      # fixed header - remaining length
      # variable header - topic - length and data
      # variable header - packet id
      # payload - properties - length and data
      # payload - message body
      publish =
        <<3::4, flag(true)::1, 3::2, flag(true)::1>> <>
          <<17>> <>
          <<5::16, "topic">> <>
          <<4::16>> <>
          <<0>> <>
          <<"message">>

      {type, _error} = Packet.decode(publish)
      assert type == :unknown
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

      {type, packet} = Packet.decode(subscribe)

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
      {type, _} = Packet.decode(<<0, 2, 0, 0>>)
      assert type == :unknown
    end
  end

  test "can parse one length variable length ints" do
    assert Packet.Decode.variable_length_prefixed(<<0, 0>>) == {0, 1, <<0>>}
    assert Packet.Decode.variable_length_prefixed(<<127, 0>>) == {127, 1, <<0>>}
  end

  test "can parse two length variable length ints" do
    assert Packet.Decode.variable_length_prefixed(<<128, 1, 0>>) == {128, 2, <<0>>}
    assert Packet.Decode.variable_length_prefixed(<<255, 127, 0>>) == {16_383, 2, <<0>>}
  end

  test "can parse three length variable length ints" do
    assert Packet.Decode.variable_length_prefixed(<<128, 128, 1, 0>>) == {16_384, 3, <<0>>}
    assert Packet.Decode.variable_length_prefixed(<<255, 255, 127, 0>>) == {2_097_151, 3, <<0>>}
  end

  test "can parse four length variable length ints" do
    assert Packet.Decode.variable_length_prefixed(<<128, 128, 128, 1, 0>>) ==
             {2_097_152, 4, <<0>>}

    assert Packet.Decode.variable_length_prefixed(<<255, 255, 255, 127, 0>>) ==
             {268_435_455, 4, <<0>>}
  end

  test "max variable length bytes is 4" do
    assert_raise RuntimeError, ~r/error/, fn ->
      Packet.Decode.variable_length_prefixed(<<255, 255, 255, 255, 7>>)
    end
  end

  defp flag(f) when f in [0, nil, false], do: 0
  defp flag(_), do: 1
end
