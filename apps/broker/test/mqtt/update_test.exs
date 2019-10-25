defmodule Mqtt.UpdateTest do
  use ExUnit.Case
  import Mqtt.Update
  @default_state {:a_socket, ""}

  test "pingreq returns pingresp command" do
    mississippi = {:hi, :bob}
    {state, commands} = Mqtt.Update.update({:pingreq}, mississippi)

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

    assert Enum.at(commands, 0) == Broker.Command.register_clientid("qwerty", self())

    assert Enum.at(commands, 1) ==
             Broker.Command.start_new_session("qwerty") <|> (&Broker.Command.send_connack/1)
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

    assert Enum.at(commands, 0) == Broker.Command.register_clientid("qwerty", self())

    assert Enum.at(commands, 1) ==
             Broker.Command.continue_session("qwerty") <|> (&Broker.Command.send_connack/1)
  end

  test "compose operator composes functions properly sum/div" do
    sum = fn x1 -> fn y -> x1 + y end end
    div = fn x2 -> fn y -> x2 / y end end

    sum_then_div = sum.(12) <|> div

    assert sum_then_div.(4) == 4
  end
end
