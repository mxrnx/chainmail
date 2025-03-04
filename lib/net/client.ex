defmodule Client do
  require Logger
  require String
  
  def start(socket, server_pid) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<0, 7, name::binary-size(64), password::binary-size(64), _unused::binary-size(1)>>} ->
        if Server.correct_password?(password) do
          trimmedName = String.trim_trailing(name)

          if Players.name_in_use?(trimmedName) do
            Logger.notice("Client tried to connect with name that was already in use.", name: trimmedName)

            :gen_tcp.send(socket, Packets.disconnect_player("Name already in use"))
          else
            player_id = create_player(socket, trimmedName)
            ClientUtils.send_to_all_except(player_id, Packets.spawn_player(trimmedName, player_id))
            listen(socket, server_pid, player_id)
          end
        else
          Logger.notice("Client tried to connect with incorrect password.")
          :gen_tcp.send(socket, Packets.disconnect_player("Incorrect password"))
        end

      {:ok, packet} ->
        Logger.warning("Client send unexpected packet before identification.", packet: packet)
        IO.inspect(packet, binaries: :as_binaries)

      {:error, reason} ->
        Logger.error("Could not receive from client before identification.", reason: reason)
    end
  end

  defp create_player(socket, name) do
    Logger.info("Client connecting.", name: name)

    # Get list of players before the current one is added
    other_players = Players.all()
    player_id = Players.add(name, socket)

    ClientUtils.send_to_player(player_id, Packets.server_identification("Elixir server", "Server running on elixir", false))

    # Send level
    ClientUtils.send_to_player(player_id, Packets.level_initialize())
    ClientUtils.send_level(player_id)
    ClientUtils.send_to_player(player_id, Packets.level_finalize())

    # Start pinging
    PingServer.start_link(player_id)

    # Spawn self and others
    ClientUtils.send_to_player(player_id, Packets.spawn_player(name))
    Enum.map(other_players, &ClientUtils.send_to_player(player_id, Packets.spawn_player(&1.name, &1.id)))
    ClientUtils.send_to_all(Packets.message(player_id, Messages.player_join(name)))

    Logger.info("Client connected.", name: name, player_id: player_id)

    # Return player id in order to broadcast to other players
    player_id
  end

  defp listen(socket, server_pid, player_id) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        action = handle_packet(packet, player_id)

        case action do
          {:to_all, packet} ->
            ClientUtils.send_to_all(packet)

          nil -> :ok
        end

        listen(socket, server_pid, player_id)

      {:error, reason} ->
        ClientUtils.despawn_player(player_id)
        Logger.error("Could not receive from client.", reason: reason, player_id: player_id)
    end
  end

  defp handle_packet(packet, player_id) do
    case packet do
      <<5, x::binary-size(2), y::binary-size(2), z::binary-size(2), mode::binary-size(1), block::binary-size(1)>> ->
        block_value = Level.set_block(x, y, z, mode, block)
        {:to_all, Packets.set_block(x, y, z, block_value)}

      <<8, 255, x::binary-size(2), y::binary-size(2), z::binary-size(2), yaw::binary-size(1), pitch::binary-size(1)>> ->
        {:to_all, Packets.move_player(player_id, x, y, z, yaw, pitch)}

      <<13, 255, message::binary-size(64)>> ->
        name = Players.get(player_id).name
        Logger.info("<#{name}> #{message}")
        {:to_all, Packets.message(player_id, Messages.player_message(name, message))}

      _ ->
        Logger.debug("Received unknown packet from player.",
          player_id: player_id,
          packet: Enum.join(:binary.bin_to_list(packet), " ")
        )

        nil
    end
  end
end
