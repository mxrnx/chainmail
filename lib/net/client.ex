defmodule Client do
  require Logger
  require String

  @max_chunk_size 1024

  def start(socket, server_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<0, 7, name::binary-size(64), password::binary-size(64), _unused::binary-size(1)>>} ->
        if Server.correct_password?(password) do
          trimmedName = String.trim_trailing(name)
          if (Players.name_in_use?(trimmedName)) do
            Logger.notice("Client tried to connect with name that was already in use.", [name: trimmedName])
            :gen_tcp.send(socket, Packets.disconnect_player("Name already in use"))
          else
            player_id = create_player(socket, trimmedName)
            send_to_all_except(player_id, Packets.spawn_player(trimmedName, player_id))
            listen(socket, server_pid, player_id)
          end
        else
          Logger.notice("Client tried to connect with incorrect password.")
          :gen_tcp.send(socket, Packets.disconnect_player("Incorrect password"))
        end
      {:ok, packet} ->
        Logger.warning("Client send unexpected packet before identification.", [packet: packet])
        IO.inspect(packet, binaries: :as_binaries)
      {:error, reason} ->
        Logger.error("Could not receive from client.", [reason: reason])
    end
  end

  def send_to_player(player_id, packet) do
    socket = Players.get(player_id).socket
    send_to_socket(socket, packet, player_id)
  end

  def send_to_all(packet) do
    Enum.map(Players.all(), & send_to_socket(&1.socket, packet, &1.id))
  end

  def send_to_all_except(player_id, packet) do
    Enum.map(Enum.reject(Players.all(), &(&1.id == player_id)), & send_to_socket(&1.socket, packet, &1.id))
  end

  defp send_to_socket(socket, packet, player_id) do
    case :gen_tcp.send(socket, packet) do
      :ok -> :ok
      {:error, _reason} ->
        despawn_player(player_id)
    end
  end

  defp create_player(socket, name) do
    Logger.info("Client connecting.", [name: name])
    other_players = Players.all() # Get list of players before the current one is added
    player_id = Players.add(name, socket)
    send_to_player(player_id, Packets.server_identification("Elixir server", "Server running on elixir", false))

    send_to_player(player_id, Packets.level_initialize())
    send_level(player_id)
    send_to_player(player_id, Packets.level_finalize())

    send_to_player(player_id, Packets.ping()) # TODO: can be removed, pings should happen on a timer

    # Spawn self and others
    send_to_player(player_id, Packets.spawn_player(name))
    Enum.map(other_players, & send_to_player(player_id, Packets.spawn_player(&1.name, &1.id)))
    send_to_all(Packets.message(player_id, Messages.player_join(name)))
    
    Logger.info("Client connected.", [name: name, player_id: player_id])

    player_id # return player id in order to broadcast to other players
  end

  defp send_level(player_id) do
    Level.to_gzip()
    |> to_list
    |> chunk_every(@max_chunk_size)
    |> send_chunks(player_id)
  end

  defp send_chunks([chunk], player_id) do
    send_chunk(chunk, player_id)
  end

  defp send_chunks([chunk | chunks], player_id) do
    Logger.debug("Sending #{length(chunks) + 1} chunks", [player_id: player_id])
    send_chunk(chunk, player_id)
    send_chunks(chunks, player_id)
  end

  defp send_chunk(chunk, player_id) do
    send_to_player(player_id, Packets.level_data_chunk(chunk))
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

  defp handle_packet(packet, player_id) do
    case packet do
      << 5, x::binary-size(2), y::binary-size(2), z::binary-size(2), mode::binary-size(1), block::binary-size(1) >> ->
        block_value = Level.set_block(x, y, z, mode, block)
        {:to_all, Packets.set_block(x, y, z, block_value)}
      << 8, 255, x::binary-size(2), y::binary-size(2), z::binary-size(2), yaw::binary-size(1), pitch::binary-size(1) >> ->
        {:to_all, Packets.move_player(player_id, x, y, z, yaw, pitch)}
      << 13, 255, message::binary-size(64) >> ->
        name = Players.get(player_id).name
        Logger.info("<#{name}> #{message}")
        {:to_all, Packets.message(player_id, Messages.player_message(name, message))}
      _ ->
        Logger.debug("Received unknown packet from player.", [player_id: player_id, packet: Enum.join(:binary.bin_to_list(packet), " ")])
        nil
    end
  end

  defp listen(socket, server_pid, player_id) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        action = handle_packet(packet, player_id)
        case action do
          {:to_all, packet} ->
            send_to_all(packet)
          {:to_all_except, player_id, packet} ->
            send_to_all_except(player_id, packet)
          nil -> :ok
        end
        listen(socket, server_pid, player_id)
      {:error, reason} ->
        despawn_player(player_id)
        Logger.error("Could not receive from client.", [reason: reason, player_id: player_id])
    end
  end

  defp despawn_player(player_id) do
    Logger.debug("Trying to despawn player.", [player_id: player_id])
    player = Players.get(player_id)
    if player do
      Logger.info("Despawning player.", [player_id: player_id])
      Players.remove(player_id)
      send_to_all(Packets.message(player.id, Messages.player_leave(player.name)))
      send_to_all(Packets.despawn_player(player.id))
    end
  end
end
