defmodule Client do
  require Logger
  require String
  
  @max_chunk_size 1024
  
  def start(socket, server_pid) do
    spawn_link(fn -> listen(socket, server_pid) end)
  end
  
  defp create_player(socket, packet_contents, username, _password) do
    # TODO: password check
    Logger.info(username)
    sender_pid = spawn_link(fn -> client_sender(socket, packet_contents) end)
    Players.add(username, sender_pid)
    send(sender_pid, Packets.server_identification("Elixir server", "Server running on elixir", false))
    Process.sleep(800)
    send(sender_pid, Packets.level_initialize())
    Process.sleep(800)
    send_level(sender_pid)
    Logger.info("hey hoi")
    send(sender_pid, Packets.level_finalize())
    Process.sleep(800)
    send(sender_pid, Packets.ping())
    Process.sleep(800)
    send(sender_pid, Packets.ping())
    Process.sleep(800)
    # TODO: BROADCAST
    send(sender_pid, Packets.spawn_player())
    #Registry.register(ClientSenders, 1, pid)
  end
  
  defp send_level(sender_pid) do
    Level.to_gzip()
      |> log
      |> to_list
      |> chunk_every(@max_chunk_size)
      |> send_chunks(sender_pid)
  end
  
  defp send_chunks([chunk], sender_pid) do
    Logger.info("next chunk")
    send(sender_pid, Packets.level_data_chunk(chunk))
    Process.sleep(800)
  end
  
  defp send_chunks([chunk | chunks], sender_pid) do
    Logger.info("#{length(chunks) + 1} chunks")
    send(sender_pid, Packets.level_data_chunk(chunk))
    Process.sleep(800)
    send_chunks(chunks, sender_pid)
  end
  
  defp to_list(<< head::8 >>) do
    [head]
  end
  
  defp to_list(<< head::8, tail::binary >>) do
    [head | to_list(tail)]
  end
  
  defp chunk_every(data, max_size) do
    if (length(data) <= max_size) do
      [data]
    else
      [Enum.take(data, max_size) | chunk_every(Enum.drop(data, max_size), max_size)]
    end
  end
  
  def log(x) do
    if is_binary(x) do
      Logger.info("binary")
    else
      Logger.info("not binary")
    end
    x
  end
  
  defp client_sender(socket, packet_contents) do
    receive do
      << id >> <> packet -> 
        Logger.info("Sending packet #{id}")
        status = :gen_tcp.send(socket, <<id>> <> packet)
        Logger.info("Done! #{status}")
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
        #IO.inspect(packet, binaries: :as_binaries)
        handle_packet(socket, packet)
        listen(socket, server_pid)
      {:error, reason} -> 
        Logger.error("Could not receive from client: #{reason}")
    end
  end
end
