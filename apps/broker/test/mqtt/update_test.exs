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
    connect = {:connect, %{client_id: "qwerty", clean_session: true}}
    {_, commands} = Mqtt.Update.update(connect, @default_state)

    assert Enum.at(commands, 0) == Broker.Command.register_clientid("qwerty", self())
    assert Enum.at(commands, 1) == Broker.Command.start_new_session("qwerty") <|> &Broker.Command.send_connack/1
  end

  test "on connect without clean session, register client id and continue session" do
    connect = {:connect, %{client_id: "qwerty", clean_session: false}}
    {_, commands} = Mqtt.Update.update(connect, @default_state)

    assert Enum.at(commands, 0) == Broker.Command.register_clientid("qwerty", self())
    assert Enum.at(commands, 1) == Broker.Command.continue_session("qwerty") <|> &Broker.Command.send_connack/1
  end

end
