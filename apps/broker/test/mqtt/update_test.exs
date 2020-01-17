defmodule Mqtt.UpdateTest do
  use ExUnit.Case
  import Mqtt.Update

  @default_state %Mqtt.Update.State{
    socket: :a_socket,
    client_id: ""
  }

  test "pingreq returns pingresp command" do
    mississippi = {:hi, :bob}
    {state, commands} = Mqtt.Update.update({:pingreq, %Packet.Pingreq{}}, mississippi)

    assert state == mississippi
    assert Enum.at(commands, 0) == Broker.Command.send_pingresp()
  end

  test "on connect with clean session, register client id and start a session" do
    connect =
      {:connect,
       %Packet.Connect{
         client_id: "qwerty",
         clean_session: true,
         protocol_level: 5,
         keep_alive: 60
       }}

    {_, commands} = Mqtt.Update.update(connect, @default_state)

    assert Enum.at(commands, 0) == Broker.Command.register_client_id("qwerty", self())
    assert Enum.at(commands, 1) == Broker.Command.start_new_session("qwerty")
  end

  test "on connect without clean session, register client id and continue session" do
    connect =
      {:connect,
       %Packet.Connect{
         client_id: "qwerty",
         clean_session: false,
         protocol_level: 5,
         keep_alive: 60
       }}

    {_, commands} = Mqtt.Update.update(connect, @default_state)

    assert Enum.at(commands, 0) == Broker.Command.register_client_id("qwerty", self())
    assert Enum.at(commands, 1) == Broker.Command.continue_session("qwerty")
  end

  test "on publish with qos 1, save in-flight packet id and schedule publish" do
    pub_packet = %Packet.Publish{
      topic: "a/topic",
      message: "hello",
      qos: 1,
      retain: false,
      packet_id: 0x0501,
      dup: false
    }

    pub_event = {:publish_qos1, pub_packet}

    {state, commands} = Mqtt.Update.update(pub_event, @default_state)

    assert commands == [Broker.Command.schedule_publish(pub_packet)]
  end

  test "compose operator composes functions properly sum/div" do
    sum = fn x1 -> fn y -> x1 + y end end
    div = fn x2 -> fn y -> x2 / y end end

    sum_then_div = sum.(12) <|> div

    assert sum_then_div.(4) == 4
  end
end
