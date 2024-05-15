defmodule Client do
  require Logger
  require String
  
  @max_chunk_size 1024
  
  def start(socket, server_pid) do
    spawn_link(fn -> listen_for_identification(socket, server_pid) end)
  end
  
  defp create_player(socket, name) do
    # TODO: password check
    Logger.info("Client connecting with name #{name}")
    sender_pid = spawn_link(fn -> client_sender(socket) end)
    other_players = Players.all() # Get list of players before the current one is added
    player_id = Players.add(name, sender_pid)
    send(sender_pid, Packets.server_identification("Elixir server", "Server running on elixir", false))

    send(sender_pid, Packets.level_initialize())
    send_level(sender_pid)
    send(sender_pid, Packets.level_finalize())

    send(sender_pid, Packets.ping()) # TODO: can be removed, pings should happen on a timer

    # Spawn self and others
    send(sender_pid, Packets.spawn_player(name))
    Enum.map(other_players, & send(sender_pid, Packets.spawn_player(&1.name, &1.id)))

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
  
  defp client_sender(socket) do
    receive do
      packet -> 
        :gen_tcp.send(socket, packet)
    end
    client_sender(socket)
  end
  
  defp handle_packet(packet, player_id) do
    case packet do
      <<5, x::binary-size(2), y::binary-size(2), z::binary-size(2), mode::binary-size(1), block::binary-size(1) >> ->
        block_value = Level.set_block(x, y, z, mode, block)
        {:to_all, Packets.set_block(x, y, z, block_value)}
      <<8, 255, x::binary-size(2), y::binary-size(2), z::binary-size(2), yaw::binary-size(1), pitch::binary-size(1) >> ->
        {:to_all, Packets.move_player(player_id, x, y, z, yaw, pitch)}
      _ -> 
        IO.inspect(packet, binaries: :as_binaries)
        nil
    end
  end

  defp listen_for_identification(socket, server_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<0, 7, name::binary-size(64), password::binary-size(64), _unused::binary-size(1)>>} ->
        if Server.correct_password?(password) do
          player_id = create_player(socket, name)
          send(server_pid, {:to_all_except, player_id, Packets.spawn_player(name, player_id)})
          listen(socket, server_pid, player_id)
        else
          :gen_tcp.send(socket, Packets.disconnect_player("Incorrect password"))
        end
      {:ok, packet} ->
        Logger.error("Client send unexpected packet before identification.")
        IO.inspect(packet, binaries: :as_binaries)
      {:error, reason} -> 
        Logger.error("Could not receive from client: #{reason}")
    end
  end
  
  defp listen(socket, server_pid, player_id) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} -> 
        action = handle_packet(packet, player_id)
        if action do
          send(server_pid, action)
        end
        listen(socket, server_pid, player_id)
      {:error, reason} -> 
        Logger.error("Could not receive from client: #{reason}")
    end
  end
end
