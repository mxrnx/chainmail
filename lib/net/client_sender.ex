defmodule ClientSender do
  use GenServer
  
  require Logger

  @max_chunk_size 1024
  
  # -- Public API --
  
  def start_link(socket) do
    GenServer.start_link(__MODULE__, {socket, nil})
  end
  
  def set_player_id(pid, player_id) do
    GenServer.cast(pid, {:set_player_id, player_id})
  end
  
  def send_ping(pid) do
    GenServer.cast(pid, :send_ping)
  end
  
  def send_packet(pid, packet) do
    GenServer.cast(pid, {:send_packet, packet})
  end
  
  def send_level(pid) do
    GenServer.cast(pid, :send_level)
  end
  
  def disconnect_player(pid, message) do
    GenServer.cast(pid, {:disconnect_player, message})
  end
  
  # -- Callbacks --
  
  @impl true
  def init({socket, nil}) do
    Logger.debug("Starting ClientSender")
    
    # Start pinging
    PingServer.start_link(self())
    
    {:ok, {socket, nil}}
  end
  
  @impl true
  def handle_cast({:set_player_id, player_id}, {socket, _}) do
    {:noreply, {socket, player_id}}
  end
  
  @impl true
  def handle_cast(:send_ping, {socket, player_id}) do
    send_packet(Packets.ping())
    {:noreply, {socket, player_id}}
  end
  
  @impl true
  def handle_cast({:send_packet, packet}, {socket, player_id}) do
    case Tcp.send(socket, packet) do
      :ok ->
        {:noreply, {socket, player_id}}
      {:error, _reason} ->
        ClientBroadcaster.despawn_player(player_id)
        {:stop, :shutdown, {socket, player_id}}
    end
  end

  def handle_cast(:send_level, {socket, player_id}) do
    send_packet(Packets.level_initialize())
    Level.to_gzip()
    |> binary_to_list
    |> chunk_every(@max_chunk_size)
    |> send_chunks

    {:noreply, {socket, player_id}}
  end

  def handle_cast({:disconnect_player, message}, {socket, player_id}) do
    Tcp.disconnect(socket, message)
    {:noreply, {socket, player_id}}
  end
  
  # -- Private helpers --

  defp send_packet(packet) do
    send_packet(self(), packet)
  end

  defp send_chunks([chunk]) do
    send_chunk(chunk)
    send_packet(Packets.level_finalize()) # Send finalize after last chunk
  end
  
  defp send_chunks([chunk | chunks]) do
    Logger.debug("Sending #{length(chunks) + 1} chunks")
    send_chunk(chunk)
    send_chunks(chunks) # Since there are more chunks, continue sending those
  end

  defp send_chunk(chunk) do
    send_packet(Packets.level_data_chunk(chunk))
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