defmodule Client do
  require Logger
  require String
  
  def start(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<0, 7, name::binary-size(64), password::binary-size(64), _unused::binary-size(1)>>} ->
        if Server.correct_password?(password) do
          trimmedName = String.trim_trailing(name)

          if Players.name_in_use?(trimmedName) do
            Logger.notice("Client tried to connect with name that was already in use.", name: trimmedName)

            Tcp.disconnect(socket, "Name already in use")
          else
            player_id = create_player(socket, trimmedName)
            ClientBroadcaster.send_to_all_except(player_id, Packets.spawn_player(trimmedName, player_id))
            listen(socket, player_id)
          end
        else
          Logger.notice("Client tried to connect with incorrect password.")
          Tcp.disconnect(socket, "Incorrect password")
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

    # Start up sender for the player, which in turn starts up a ping server to keep the connection alive
    {:ok, client_sender_id} = ClientSender.start_link(socket)
    player_id = Players.add(name, client_sender_id)
    ClientSender.set_player_id(client_sender_id, player_id)

    ClientSender.send_packet(client_sender_id, Packets.server_identification("Elixir server", "Server running on elixir", false))

    # Send level
    ClientSender.send_level(client_sender_id)

    # Spawn self and others
    ClientBroadcaster.spawn_player(player_id)

    Logger.info("Client connected.", name: name, player_id: player_id)

    # Return player id in order to broadcast to other players
    player_id
  end

  # TODO: split listener logic away from client initialization logic
  defp listen(socket, player_id) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        action = handle_packet(packet, player_id)

        case action do
          {:to_all, packet} ->
            ClientBroadcaster.send_to_all(packet)

          nil -> :ok
        end

        listen(socket, player_id)

      {:error, reason} ->
        ClientBroadcaster.despawn_player(player_id)
        Logger.debug("Could not receive from client.", reason: reason, player_id: player_id)
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

        # TODO: parse commands

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
