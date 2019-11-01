defprotocol Packet.Encodable do
  @moduledoc false

  @spec encode(Packet.message()) :: iodata()
  def encode(package)
end
