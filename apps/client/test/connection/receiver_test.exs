defmodule Connection.ReceiverTest do
  use ExUnit.Case
  doctest Connection.Receiver

  alias Connection.Receiver

  setup context do
    _ = start_supervised!({Registry, keys: :unique, name: Client.Bucket})

    {:ok, %{client_id: context.test}}
  end

  def setup_connection(context) do
    {:ok, client_socket, server_socket} = TestHelper.FakeTCPThing.new()
    {:ok, Map.merge(context, %{client: client_socket, server: server_socket})}
  end

  def setup_receiver(context) do
    {:ok, pid} = Receiver.start_link(client_id: context.client_id, socket: context.client)
    :ok = Receiver.handle_socket(pid, context.client)
    {:ok, %{receiver_pid: pid}}
  end

  def setup_client(context) do
    Registry.register(Client.Bucket, {Client, context.client_id}, self())
    :ok
  end

  describe "receiving things" do
    setup [:setup_connection, :setup_receiver, :setup_client]

    test "receive a publish with a small payload", context do
      message = :crypto.strong_rand_bytes(1448)
      publish = %Packet.Publish{packet_id: 1, qos: 1, topic: "another/one", message: message}

      :ok = :gen_tcp.send(context.server, Packet.encode(publish))

      assert_receive {:"$gen_call", caller, {:receive_packet, {:publish_qos1, ^publish}}}
    end

    test "receive a publish with a big ol payload", context do
      message = :crypto.strong_rand_bytes(120_000)
      publish = %Packet.Publish{packet_id: 1, qos: 1, topic: "another/one", message: message}

      :ok = :gen_tcp.send(context.server, Packet.encode(publish))

      assert_receive {:"$gen_call", caller, {:receive_packet, {:publish_qos1, ^publish}}}
    end

    test "very slow connection", context do
      Process.flag(:trap_exit, true)
      receiver_pid = context.receiver_pid

      # make sure we don't crash the receiver by sending one byte.....then waiting
      :ok = :gen_tcp.send(context.server, <<0b11010000>>)
      refute_receive {:EXIT, ^receiver_pid, {:protocol_violation, :invalid_header_length}}, 400

      # send the second byte and make sure we get the right packet
      :ok = :gen_tcp.send(context.server, <<0>>)
      assert_receive {:"$gen_call", caller, {:receive_packet, packet}}, 10000
      assert {:pingresp, %Packet.Pingresp{}} == packet
    end
  end

  describe "bad packets" do
    setup [:setup_connection, :setup_receiver]

    test "invalid header length", context do
      Process.flag(:trap_exit, true)
      receiver_pid = context.receiver_pid
      # send more bytes than the fixed header size
      # the header parser should return protocol violation
      :ok = :gen_tcp.send(context.server, <<1, 255, 255, 255, 255, 0>>)
      assert_receive {:EXIT, ^receiver_pid, {:protocol_violation, :invalid_header_length}}
    end
  end

  describe "closed socket" do
    setup [:setup_connection, :setup_receiver]

    test "closing the sockets does not crash the pid", context do
      :ok = :gen_tcp.close(context.client)
      :ok = :gen_tcp.close(context.server)

      assert Process.alive?(context.receiver_pid)
    end
  end
end
