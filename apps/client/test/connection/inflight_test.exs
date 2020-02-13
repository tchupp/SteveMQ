defmodule Connection.InflightTest do
  use ExUnit.Case
  doctest Connection.Inflight

  alias Connection.Inflight

  setup context do
    _ = start_supervised!({Registry, keys: :unique, name: Client.Bucket})

    {:ok, %{client_id: context.test}}
  end

  def setup_connection(context) do
    {:ok, client_socket, server_socket} = TestHelper.FakeTCPThing.new()
    {:ok, Map.merge(context, %{client: client_socket, server: server_socket})}
  end

  defp drop_connection(%{server: server} = context) do
    :ok = :gen_tcp.close(server)
    {:ok, Map.drop(context, [:client, :server])}
  end

  def setup_inflight(context) do
    {:ok, pid} = Inflight.start_link(client_id: context.client_id, socket: context.client)
    :ok = Inflight.connect(pid, context.client)
    {:ok, %{inflight_pid: pid}}
  end

  describe "lifecycle" do
    setup [:setup_connection]

    test "Inflight.stop/1 stops the pid", context do
      assert {:ok, pid} =
               Inflight.start_link(client_id: context.client_id, socket: context.client)

      assert Process.alive?(pid)
      assert :ok == Inflight.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "incoming" do
    setup [:setup_connection, :setup_inflight]

    test "incoming qos 0 publish, does not send anything", %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: 142, topic: "test/topic", message: "message 0", qos: 0}
      :ok = Inflight.receive(client_id, publish)

      assert {:error, :timeout} == :gen_tcp.recv(context.server, 0, 500)
    end

    test "incoming qos 1 publish, sends puback to server", %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: 589, topic: "test/topic", message: "message 1", qos: 1}
      :ok = Inflight.receive(client_id, publish)

      assert {:ok, puback} = :gen_tcp.recv(context.server, 0, 500)

      assert {:puback, %Packet.Puback{packet_id: 589, status: {:accepted, :ok}}} ==
               Packet.decode(puback)
    end
  end

  describe "outgoing" do
    setup [:setup_connection, :setup_inflight]

    test "outgoing qos 0 publish", %{client_id: client_id} = context do
      publish = %Packet.Publish{topic: "other/topic", qos: 0, message: "message 17"}
      {:ok, ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos0, ^publish} = Packet.decode(packet)

      # the caller should not get a response
      refute_receive {{Inflight, ^client_id}, ^ref, :ok}
    end

    test "outgoing qos 1 publishes, will be assigned a packet_id",
         %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: nil, topic: "other/topic", qos: 1, message: "message1"}
      {:ok, _ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos1, received_publish1} = Packet.decode(packet)
      # make sure a packet_id was assigned
      assert received_publish1.packet_id != nil

      publish = %Packet.Publish{packet_id: nil, topic: "other/topic", qos: 1, message: "message2"}
      {:ok, _ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos1, received_publish2} = Packet.decode(packet)
      # make sure a packet_id was assigned
      assert received_publish2.packet_id != nil

      # make sure the packet_ids were not the same
      assert received_publish1.packet_id != received_publish2.packet_id
    end

    test "outgoing qos 1 publish, responds to caller with ref",
         %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: 1, topic: "other/topic", qos: 1, message: "message 17"}
      {:ok, ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos1, ^publish} = Packet.decode(packet)

      # the caller should not get a response, until puback
      refute_receive {{Inflight, ^client_id}, ^ref, :ok}

      # receive a puback from the server
      :ok = Inflight.receive(client_id, %Packet.Puback{packet_id: 1, status: {:accepted, :ok}})

      # the calling process should get a response
      assert_receive {{Inflight, ^client_id}, ^ref, :ok}
    end

    test "outgoing qos 1 publish, sends publish with duplicate flag on reconnect",
         %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: 1, topic: "other/topic", qos: 1, message: "message 17"}
      {:ok, _ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos1, ^publish} = Packet.decode(packet)

      # drop and reestablish the connection
      {:ok, context} = drop_connection(context)
      {:ok, context} = setup_connection(context)
      Inflight.disconnect(client_id)
      Inflight.connect(client_id, context.client)

      # the inflight process should now re-transmit the publish
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      publish = %Packet.Publish{publish | dup: true}
      assert {:publish_qos1, ^publish} = Packet.decode(packet)
    end

    test "outgoing qos 1 publish, only sends publish until puback is received",
         %{client_id: client_id} = context do
      publish = %Packet.Publish{packet_id: 1, topic: "other/topic", qos: 1, message: "message 17"}
      {:ok, _ref} = Inflight.track_outgoing(client_id, publish)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:publish_qos1, ^publish} = Packet.decode(packet)

      # drop and reestablish the connection
      {:ok, context} = drop_connection(context)
      {:ok, context} = setup_connection(context)
      Inflight.disconnect(client_id)
      Inflight.connect(client_id, context.client)

      # the inflight process should now re-transmit the publish
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      publish = %Packet.Publish{publish | dup: true}
      assert {:publish_qos1, ^publish} = Packet.decode(packet)

      # receive a puback from the server
      :ok = Inflight.receive(client_id, %Packet.Puback{packet_id: 1, status: {:accepted, :ok}})

      # drop and reestablish the connection
      {:ok, context} = drop_connection(context)
      {:ok, context} = setup_connection(context)
      Inflight.disconnect(client_id)
      Inflight.connect(client_id, context.client)

      assert {:error, :timeout} = :gen_tcp.recv(context.server, 0, 500)
    end

    test "outgoing qos 1 publishes, are sent in order when the connection is opened",
         %{client_id: client_id} = context do
      # drop the connection
      Inflight.disconnect(client_id)

      publish1 = %Packet.Publish{packet_id: 1, topic: "other/topic", qos: 1, message: "message1"}
      publish2 = %Packet.Publish{packet_id: 2, topic: "other/topic", qos: 1, message: "message2"}

      {:ok, _ref} = Inflight.track_outgoing(client_id, publish1)
      {:ok, _ref} = Inflight.track_outgoing(client_id, publish2)

      # reestablish the connection
      Inflight.connect(client_id, context.client)

      # we expect the publishes to have the duplicate flag now
      publish1 = %Packet.Publish{publish1 | dup: true}
      publish2 = %Packet.Publish{publish2 | dup: true}

      expected = Packet.encode(publish1) |> IO.iodata_to_binary()
      assert {:ok, ^expected} = :gen_tcp.recv(context.server, byte_size(expected), 500)
      expected = Packet.encode(publish2) |> IO.iodata_to_binary()
      assert {:ok, ^expected} = :gen_tcp.recv(context.server, byte_size(expected), 500)
    end

    test "outgoing publishes timeout, when the sockets are closed", context do
      :ok = :gen_tcp.close(context.server)
      :ok = :gen_tcp.close(context.client)

      publish = %Packet.Publish{topic: "other/topic", qos: 0, message: "message 17"}
      {:ok, ref} = Inflight.track_outgoing(context.client_id, publish)
      {:error, :timeout} = Inflight.await(context.client_id, ref, 3000)

      assert Process.alive?(context.inflight_pid)
    end
  end

  describe "outgoing subscribe" do
    setup [:setup_connection, :setup_inflight]

    test "outgoing subscribe, responds to caller with ref", %{client_id: client_id} = context do
      subscribe = %Packet.Subscribe{packet_id: 1, topics: [{"other/topic", 1}]}
      {:ok, ref} = Inflight.track_outgoing(client_id, subscribe)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:subscribe, ^subscribe} = Packet.decode(packet)

      # the caller should not get a response, until puback
      refute_receive {{Inflight, ^client_id}, ^ref, :ok}

      # receive a puback from the server
      :ok = Inflight.receive(client_id, %Packet.Suback{packet_id: 1})

      # the calling process should get a response
      assert_receive {{Inflight, ^client_id}, ^ref, :ok}
    end

    test "outgoing subscribe, will be assigned a packet_id",
         %{client_id: client_id} = context do
      subscribe = %Packet.Subscribe{packet_id: nil, topics: [{"topic1", 1}]}
      {:ok, _ref} = Inflight.track_outgoing(client_id, subscribe)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:subscribe, received_subscribe1} = Packet.decode(packet)
      # make sure a packet_id was assigned
      assert received_subscribe1.packet_id != nil

      subscribe = %Packet.Subscribe{packet_id: nil, topics: [{"topic2", 1}]}
      {:ok, _ref} = Inflight.track_outgoing(client_id, subscribe)
      assert {:ok, packet} = :gen_tcp.recv(context.server, 0, 500)
      assert {:subscribe, received_subscribe2} = Packet.decode(packet)
      # make sure a packet_id was assigned
      assert received_subscribe2.packet_id != nil

      # make sure the packet_ids were not the same
      assert received_subscribe1.packet_id != received_subscribe2.packet_id
    end
  end
end
