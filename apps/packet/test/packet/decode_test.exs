defmodule Packet.DecodeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Packet.Encode2

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
      assert type == :connect_error
    end
  end

  describe "CONNACK" do
    property "decodes CONNACK - session_present" do
      check all session_present? <- StreamData.boolean() do
        # session present size
        # return code size
        # properties length size
        packet_length = 3

        connack =
          <<2::4, 0::4>> <>
            <<packet_length::8>> <>
            <<0::7, flag(session_present?)::1>> <>
            <<0::8>> <>
            <<0::8>>

        {:connack, %Packet.Connack{session_present?: actual?}} = Packet.decode(connack)

        assert session_present? == actual?
      end
    end

    property "decodes CONNACK - known statuses" do
      return_codes = [
        {0x00, :accepted},
        {0x01, {:refused, :unacceptable_protocol_version}},
        {0x02, {:refused, :identifier_rejected}},
        {0x03, {:refused, :server_unavailable}},
        {0x04, {:refused, :bad_user_name_or_password}},
        {0x05, {:refused, :not_authorized}}
      ]

      check all {return_code, status} <- StreamData.member_of(return_codes) do
        # session present size
        # return code size
        packet_length = 3

        connack =
          <<2::4, 0::4>> <>
            <<packet_length::8>> <>
            <<0::7, flag(false)::1>> <>
            <<return_code::8>> <>
            <<0::8>>

        {:connack, %Packet.Connack{status: actual}} = Packet.decode(connack)

        assert status == actual
      end
    end

    property "decodes CONNACK - unknown statuses" do
      check all return_code <- StreamData.byte(), return_code > 6 do
        packet_length = 3

        connack =
          <<2::4, 0::4>> <>
            <<packet_length::8>> <>
            <<0::7, flag(false)::1>> <>
            <<return_code::8>> <>
            <<0::8>>

        assert Packet.decode(connack) == {
                 :connack_error,
                 "unknown return_code. return_code=#{return_code}"
               }
      end
    end

    property "decodes CONNACK - fails for unknown variable header data" do
      check all variable_header <- StreamData.binary(min_length: 3),
                binary_part(variable_header, 0, 1) > <<1>> do
        packet_length = byte_size(variable_header)

        connack =
          <<2::4, 0::4>> <>
            <<packet_length::8>> <>
            variable_header

        expected = {:connack_error, "unknown variable_header"}

        assert Packet.decode(connack) == expected
      end
    end
  end

  describe "PUBLISH" do
    property "decode PUBLISH - message, ignores extra characters (anything past 7)" do
      check all message <- StreamData.string(:alphanumeric, min_length: 7),
                topic <- StreamData.string(:alphanumeric, min_length: 1),
                retain <- StreamData.boolean() do
        qos_code = 0
        qos_key = :publish_qos0
        topic_length = byte_size(topic)
        message_length = 7

        packet_length =
          2 +
            topic_length +
            1 +
            message_length

        # fixed header - packet type, flags
        # fixed header - remaining length
        # variable header - topic - length and data
        publish =
          <<3::4, 0::1, qos_code::2, flag(retain)::1>> <>
            variable_length_int(packet_length) <>
            <<topic_length::16, topic::binary>> <>
            <<0>> <>
            <<message::binary>>

        assert Packet.decode(publish) == {
                 qos_key,
                 %Packet.Publish{
                   topic: topic,
                   message: String.slice(message, 0, 7),
                   qos: qos_code,
                   retain: retain
                 }
               }
      end
    end

    property "decode PUBLISH - qos 0" do
      check all message <- StreamData.string(:alphanumeric, min_length: 0),
                topic <- StreamData.string(:alphanumeric, min_length: 1),
                retain <- StreamData.boolean() do
        qos_code = 0
        topic_length = byte_size(topic)
        message_length = byte_size(message)

        packet_length =
          2 +
            topic_length +
            1 +
            message_length

        # fixed header - packet type, flags
        # fixed header - remaining length
        # variable header - topic - length and data
        publish =
          <<3::4, 0::1, qos_code::2, flag(retain)::1>> <>
            variable_length_int(packet_length) <>
            <<topic_length::16, topic::binary>> <>
            <<0>> <>
            <<message::binary>>

        assert Packet.decode(publish) == {
                 :publish_qos0,
                 %Packet.Publish{
                   topic: topic,
                   message: message,
                   qos: qos_code,
                   retain: retain
                 }
               }
      end
    end

    property "decode PUBLISH - qos 1/2" do
      publish_qos = [
        {1, :publish_qos1},
        {2, :publish_qos2}
      ]

      check all message <- StreamData.string(:alphanumeric, min_length: 0),
                topic <- StreamData.string(:alphanumeric, min_length: 1),
                dup <- StreamData.boolean(),
                retain <- StreamData.boolean(),
                packet_id <- StreamData.positive_integer(),
                {qos_code, qos_key} <- StreamData.member_of(publish_qos) do
        topic_length = byte_size(topic)
        message_length = byte_size(message)

        packet_length =
          2 +
            topic_length +
            2 +
            1 +
            message_length

        # fixed header - packet type, flags
        # fixed header - remaining length
        # variable header - topic - length and data
        publish =
          <<3::4, flag(dup)::1, qos_code::2, flag(retain)::1>> <>
            variable_length_int(packet_length) <>
            <<topic_length::16, topic::binary>> <>
            <<packet_id::16>> <>
            <<0>> <>
            <<message::binary>>

        assert Packet.decode(publish) == {
                 qos_key,
                 %Packet.Publish{
                   topic: topic,
                   message: message,
                   qos: qos_code,
                   retain: retain,
                   packet_id: packet_id,
                   dup: dup
                 }
               }
      end
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

      {type, error} = Packet.decode(publish)
      assert type == :publish_error
      assert error == "unsupported qos. qos=3"
    end
  end

  describe "PUBACK" do
    property "decode PUBACK - packet_id" do
      check all packet_id <- StreamData.positive_integer() do
        # packet id size
        packet_length = 2

        puback =
          <<4::4, 0::4>> <>
            variable_length_int(packet_length) <>
            <<packet_id::16>>

        {:puback, %Packet.Puback{packet_id: actual_packet_id, status: actual_status}} =
          Packet.decode(puback)

        assert packet_id == actual_packet_id
        assert {:accepted, :ok} == actual_status
      end
    end

    property "decode PUBACK - status" do
      reason_codes = [
        {0x00, {:accepted, :ok}},
        {0x10, {:accepted, :no_matching_subscribers}},
        {0x80, {:refused, :unspecified_error}},
        {0x83, {:refused, :implementation_specific_error}},
        {0x87, {:refused, :not_authorized}},
        {0x90, {:refused, :topic_name_invalid}},
        {0x91, {:refused, :packet_identifier_in_use}},
        {0x97, {:refused, :quota_exceeded}},
        {0x99, {:refused, :payload_format_invalid}}
      ]

      check all {reason_code, status} <- StreamData.member_of(reason_codes) do
        # packet id size
        # reason code size
        # properties length size
        packet_length = 4

        puback =
          <<4::4, 0::4>> <>
            variable_length_int(packet_length) <>
            <<1::16>> <>
            <<reason_code::8>> <>
            <<0::8>>

        {:puback, %Packet.Puback{status: actual_status}} = Packet.decode(puback)

        assert status == actual_status
      end
    end

    property "decodes PUBACK - unknown statuses" do
      known_statuses = [
        0x00,
        0x10,
        0x80,
        0x83,
        0x87,
        0x90,
        0x91,
        0x97,
        0x99
      ]

      check all reason_code <- StreamData.byte(),
                !(reason_code in known_statuses) do
        packet_length = 4

        puback =
          <<4::4, 0::4>> <>
            variable_length_int(packet_length) <>
            <<1::16>> <>
            <<reason_code::8>> <>
            <<0::8>>

        assert Packet.decode(puback) == {
                 :puback_error,
                 "unknown reason_code. reason_code=#{reason_code}"
               }
      end
    end
  end

  describe "PUBREC" do
  end

  describe "PUBREL" do
  end

  describe "PUBCOMP" do
  end

  describe "SUBSCRIBE" do
    property "decode SUBSCRIBE - packet_id" do
      check all packet_id <- StreamData.positive_integer(),
                topics <-
                  {StreamData.binary(), StreamData.member_of(0..2)}
                  |> StreamData.tuple()
                  |> StreamData.list_of(min_length: 1) do
        encoded_topics =
          for {topic, qos} <- topics,
              do: <<byte_size(topic)::16, topic::binary, 0::6, qos::2>>,
              into: <<>>

        # packet id size
        packet_length = 2 + 1 + byte_size(encoded_topics)

        subscribe =
          <<8::4, 2::4>> <>
            variable_length_int(packet_length) <>
            <<packet_id::16>> <>
            <<0>> <>
            encoded_topics

        assert Packet.decode(subscribe) == {
                 :subscribe,
                 %Packet.Subscribe{
                   topics: topics,
                   packet_id: packet_id
                 }
               }
      end
    end

    property "decode SUBSCRIBE - ignores topics with qos 3" do
      check all packet_id <- StreamData.positive_integer(),
                topics <-
                  {StreamData.binary(), StreamData.member_of([3])}
                  |> StreamData.tuple()
                  |> StreamData.list_of(min_length: 1) do
        encoded_topics =
          for {topic, qos} <- topics,
              do: <<byte_size(topic)::16, topic::binary, 0::6, qos::2>>,
              into: <<>>

        # packet id size
        packet_length = 2 + 1 + byte_size(encoded_topics)

        subscribe =
          <<8::4, 2::4>> <>
            variable_length_int(packet_length) <>
            <<packet_id::16>> <>
            <<0>> <>
            encoded_topics

        assert Packet.decode(subscribe) == {
                 :subscribe,
                 %Packet.Subscribe{
                   topics: [],
                   packet_id: packet_id
                 }
               }
      end
    end
  end

  describe "SUBACK" do
    property "decode SUBACK - packet identifier" do
      check all packet_id <- StreamData.positive_integer() do
        packet_length =
          2 +
            1

        suback =
          <<9::4, 0::4>> <>
            <<packet_length, packet_id::16, 0>>

        assert Packet.decode(suback) == {
                 :suback,
                 %Packet.Suback{
                   packet_id: packet_id
                 }
               }
      end
    end

    property "decode SUBACK - acks" do
      qos_possibilities = [
        0x00,
        0x01,
        0x02,
        0x80
      ]

      check all packet_id <- StreamData.positive_integer(),
                acks <-
                  StreamData.member_of(qos_possibilities) |> StreamData.list_of() do
        packet_length =
          2 +
            1 +
            length(acks)

        suback =
          <<9::4, 0::4>> <>
            <<packet_length, packet_id::16, 0>> <>
            for ack <- acks, do: <<ack::8>>, into: <<>>

        assert Packet.decode(suback) == {
                 :suback,
                 %Packet.Suback{
                   packet_id: packet_id,
                   acks: acks |> Enum.map(&suback_ack_to_tuple/1)
                 }
               }
      end
    end

    property "decode SUBACK - drops unknown acks" do
      known_qos_possibilities = [
        0x00,
        0x01,
        0x02,
        0x80
      ]

      check all packet_id <- StreamData.positive_integer(),
                ack <- StreamData.byte(),
                !(ack in known_qos_possibilities) do
        packet_length =
          2 +
            1 +
            1

        suback =
          <<9::4, 0::4>> <>
            <<packet_length, packet_id::16, 0>> <>
            <<ack>>

        assert Packet.decode(suback) == {
                 :suback,
                 %Packet.Suback{
                   packet_id: packet_id,
                   acks: []
                 }
               }
      end
    end
  end

  describe "UNSUBSCRIBE" do
  end

  describe "UNSUBACK" do
  end

  describe "PINGREQ" do
    property "decode PINGREQ" do
      check all variable_header <- StreamData.binary(),
                payload <- StreamData.binary() do
        variable_header_length = byte_size(variable_header)
        payload_length = byte_size(payload)

        packet_length =
          payload_length +
            variable_header_length

        pingreq =
          <<12::4, 0::4>> <>
            variable_length_int(packet_length) <>
            <<variable_header::binary>> <>
            <<payload::binary>>

        assert Packet.decode(pingreq) == {
                 :pingreq,
                 %Packet.Pingreq{}
               }
      end
    end
  end

  describe "PINGRESP" do
    property "decode PINGRESP" do
      check all variable_header <- StreamData.binary(),
                payload <- StreamData.binary() do
        variable_header_length = byte_size(variable_header)
        payload_length = byte_size(payload)

        packet_length =
          payload_length +
            variable_header_length

        pingresp =
          <<13::4, 0::4>> <>
            variable_length_int(packet_length) <>
            <<variable_header::binary>> <>
            <<payload::binary>>

        assert Packet.decode(pingresp) == {
                 :pingresp,
                 %Packet.Pingresp{}
               }
      end
    end
  end

  describe "DISCONNECT" do
  end

  describe "ERROR" do
    test "returns error for unrecognized message types" do
      {type, _} = Packet.decode(<<0, 2, 0, 0>>)
      assert type == :unknown
    end
  end

  describe "variable_length_prefixed" do
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
  end

  defp suback_ack_to_tuple(0x80), do: {:error, :access_denied}
  defp suback_ack_to_tuple(ack) when ack in 0x00..0x02, do: {:ok, ack}

  defp flag(f) when f in [0, nil, false], do: 0
  defp flag(_), do: 1
end
