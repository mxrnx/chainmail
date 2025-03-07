defmodule ClientBroadcaster do
  require Logger
  
  def send_to_all(packet) do
    Enum.map(Players.all(), &ClientSender.send_packet(&1.client_sender_id, packet))
  end

  def send_to_all_except(player_id, packet) do
    Enum.map(
      Enum.reject(Players.all(), &(&1.id == player_id)),
      &ClientSender.send_packet(&1.client_sender_id, packet)
    )
  end
  
  def spawn_player(player_id) do
    player = Players.get(player_id)
    
    # Send new player their own spawn packet
    ClientSender.send_packet(player.client_sender_id, Packets.spawn_player(player.name))
    
    # Send spawn packet for new player to other players
    other_players = Enum.reject(Players.all(), &(&1.id == player_id))
    Enum.map(other_players, &ClientSender.send_packet(player.client_sender_id, Packets.spawn_player(&1.name, &1.id)))
    
    # Send spawn packets for all other players to new player, so their existence is known
    send_to_all(Packets.message(player_id, Messages.player_join(player.name)))
  end
  
  def despawn_player(player_id) do
    Logger.debug("Trying to despawn player.", player_id: player_id)
    player = Players.get(player_id)

    if player do
      Logger.info("Despawning player.", player_id: player_id, name: player.name)

      Players.remove(player_id)

      send_to_all(Packets.message(player.id, Messages.player_leave(player.name)))
      send_to_all(Packets.despawn_player(player.id))
    end
  end

end
