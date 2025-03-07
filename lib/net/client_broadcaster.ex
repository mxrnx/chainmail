defmodule ClientBroadcaster do
  require Logger
  
  def send_to_all(packet) do
    Enum.map(Players.all(), &send(&1.client_sender_id, {:send_packet, packet}))
  end

  def send_to_all_except(player_id, packet) do
    Enum.map(
      Enum.reject(Players.all(), &(&1.id == player_id)),
      &send(&1.client_sender_id, {:send_packet, packet})
    )
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
