defmodule Tcp do
  require Logger
  
  def send(socket, packet) do
    Logger.debug("Sent packet " <> Integer.to_string(:binary.at(packet, 0)))
    :gen_tcp.send(socket, packet)
  end
  
  def disconnect(socket, message) do
    :gen_tcp.send(socket, Packets.disconnect_player(message))
    :gen_tcp.close(socket)
  end
end