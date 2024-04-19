defmodule Client do
  require Logger
  require String
  
  def start(socket, server_pid) do
    spawn_link(fn -> listen(socket, server_pid) end)
  end
  
  defp create_player(socket, packet_contents, username, _password) do
    # TODO: password check
    Logger.info(username)
    sender_pid = spawn_link(fn -> client_sender(socket, packet_contents) end)
    Players.add(username, sender_pid)
    send(sender_pid, Packets.server_identification("Elixir server", "Server running on elixir", false))
    send(sender_pid, Packets.level_initialize())
    #Registry.register(ClientSenders, 1, pid)
  end
  
  defp client_sender(socket, packet_contents) do
    receive do
      packet -> 
        Logger.info("Sending packet...")
        :gen_tcp.send(socket, packet)
        Logger.info("Done!")
    end
    client_sender(socket, packet_contents)
  end
  
  defp handle_packet(socket, packet) do
    case packet do
      <<0, 7, username::binary-size(64), password::binary-size(64), _unused::binary-size(1)>> -> 
        create_player(socket, packet, username, password)
    end
  end
  
  defp listen(socket, server_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} -> 
        Logger.info(packet)
        IO.inspect(packet, binaries: :as_binaries)
        handle_packet(socket, packet)
        listen(socket, server_pid)
      {:error, reason} -> 
        Logger.error("Could not receive from client: #{reason}")
    end
  end
end
