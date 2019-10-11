defmodule Mqtt.UpdateTest do
  use ExUnit.Case

  test "pingreq returns pingresp command" do
    mississippi = {:hi, :bob}
    {state, commands} = Mqtt.Update.update({:pingreq}, mississippi)

    assert state == mississippi
    assert Enum.at(commands, 0) == Broker.Command.send_pingresp()
  end

end
