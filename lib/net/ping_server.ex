defmodule PingServer do
  require Logger
  use GenServer

  # Public API to start the GenServer
  def start_link({player_id, period_in_millis}) do
    GenServer.start_link(__MODULE__, {player_id, period_in_millis}, name: __MODULE__)
  end

  @impl true
  def init({player_id, period_in_millis}) do
    Logger.warning("Starting PingServer")
    # Start with the given player_id and period, then trigger the first ping
    {:ok, {player_id, period_in_millis}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, {player_id, period_in_millis}) do
    # Send the first ping asynchronously
    send(self(), :send_ping)
    {:noreply, {player_id, period_in_millis}}
  end

  @impl true
  def handle_info(:send_ping, {player_id, period_in_millis}) do
    Logger.warning("PING for player #{player_id}")

    # Call private method to send the ping to the player
    send_to_player(player_id)

    # Schedule the next ping
    Process.send_after(self(), :send_ping, period_in_millis)

    {:noreply, {player_id, period_in_millis}}
  end

  # TODO: deduplicate
  defp send_to_player(player_id) do
    socket = Players.get(player_id).socket
    send_to_socket(socket, Packets.ping())
  end

  defp send_to_socket(socket, packet) do
    case :gen_tcp.send(socket, packet) do
      :ok -> :ok
      {:error, _reason} -> nil #TODO
    end
  end
end