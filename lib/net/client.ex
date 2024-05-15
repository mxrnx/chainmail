defmodule Client do
  require Logger
  require String
  
  @max_chunk_size 1024
  
  def start(socket, server_pid) do
    spawn_link(fn -> listen(socket, server_pid) end)
  end
  
  defp create_player(socket, packet_contents, username, _password) do
    # TODO: password check
    Logger.info("Client connecting with username #{username}")
    sender_pid = spawn_link(fn -> client_sender(socket, packet_contents) end)
    player_id = Players.add(username, sender_pid)
    send(sender_pid, Packets.server_identification("Elixir server", "Server running on elixir", false))

    send(sender_pid, Packets.level_initialize())
    send_level(sender_pid)
    send(sender_pid, Packets.level_finalize())

    send(sender_pid, Packets.ping()) # TODO: can be removed, pings should happen on a timer

    send(sender_pid, Packets.spawn_player(username))

    player_id # return player id in order to broadcast to other players
  end
  
  defp send_level(sender_pid) do
    Level.to_gzip()
      |> to_list
      |> chunk_every(@max_chunk_size)
      |> send_chunks(sender_pid)
  end
  
  defp send_chunks([chunk], sender_pid) do
    send(sender_pid, Packets.level_data_chunk(chunk))
  end
  
  defp send_chunks([chunk | chunks], sender_pid) do
    Logger.info("Sending #{length(chunks) + 1} chunks")
    send(sender_pid, Packets.level_data_chunk(chunk))
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
  
  defp client_sender(socket, packet_contents) do
    receive do
      packet -> 
        :gen_tcp.send(socket, packet)
    end
    client_sender(socket, packet_contents)
  end
  
  defp handle_packet(socket, packet) do
    case packet do
      <<0, 7, username::binary-size(64), password::binary-size(64), _unused::binary-size(1)>> -> 
        player_id = create_player(socket, packet, username, password)
        {:spawn_player, player_id, Packets.spawn_player(username, player_id)}
      <<5, x::binary-size(2), y::binary-size(2), z::binary-size(2), mode::binary-size(1), block::binary-size(1) >> ->
        block_value = Level.set_block(x, y, z, mode, block)
        {:set_block, Packets.set_block(x, y, z, block_value)}
      _ -> 
        IO.inspect(packet, binaries: :as_binaries)
        nil
    end
  end
  
  defp listen(socket, server_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} -> 
        action = handle_packet(socket, packet)
        if action do
          send(server_pid, action)
        end
        listen(socket, server_pid)
      {:error, reason} -> 
        Logger.error("Could not receive from client: #{reason}")
    end
  end
end
