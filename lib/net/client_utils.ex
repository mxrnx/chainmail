defmodule ClientUtils do
  require Logger

  @max_chunk_size 1024

  def send_to_player(player_id, packet) do
    socket = Players.get(player_id).socket
    send_to_socket(socket, packet, player_id)
  end

  def send_to_all(packet) do
    Enum.map(Players.all(), &send_to_socket(&1.socket, packet, &1.id))
  end

  def send_to_all_except(player_id, packet) do
    Enum.map(
      Enum.reject(Players.all(), &(&1.id == player_id)),
      &send_to_socket(&1.socket, packet, &1.id)
    )
  end

  defp send_to_socket(socket, packet, player_id) do
    case :gen_tcp.send(socket, packet) do
      :ok -> :ok
      {:error, _reason} ->
        despawn_player(player_id)
    end
  end

  def despawn_player(player_id) do
    Logger.debug("Trying to despawn player.", player_id: player_id)
    player = Players.get(player_id)

    if player do
      #TODO: hard close socket

      Logger.info("Despawning player.", player_id: player_id, name: player.name)
      Players.remove(player_id)
      send_to_all(Packets.message(player.id, Messages.player_leave(player.name)))
      send_to_all(Packets.despawn_player(player.id))
    end
  end

  def send_level(player_id) do
    Level.to_gzip()
    |> binary_to_list
    |> chunk_every(@max_chunk_size)
    |> send_chunks(player_id)
  end

  defp send_chunks([chunk], player_id) do
    send_chunk(chunk, player_id)
  end

  defp send_chunks([chunk | chunks], player_id) do
    Logger.debug("Sending #{length(chunks) + 1} chunks", player_id: player_id)
    send_chunk(chunk, player_id)
    send_chunks(chunks, player_id)
  end

  defp send_chunk(chunk, player_id) do
    send_to_player(player_id, Packets.level_data_chunk(chunk))
  end

  defp binary_to_list(<<head::8>>) do
    [head]
  end

  defp binary_to_list(<<head::8, tail::binary>>) do
    [head | binary_to_list(tail)]
  end

  defp chunk_every(data, max_size) do
    if length(data) <= max_size do
      [data]
    else
      [Enum.take(data, max_size) | chunk_every(Enum.drop(data, max_size), max_size)]
    end
  end

end