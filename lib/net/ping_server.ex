defmodule PingServer do
  require Logger
  use GenServer

  @period_in_millis 3000

  # Public API to start the GenServer
  def start_link(player_id) do
    GenServer.start_link(__MODULE__, player_id, name: __MODULE__)
  end

  @impl true
  def init(player_id) do
    Logger.warning("Starting PingServer")
    # Start with the given player_id and period, then trigger the first ping
    {:ok, player_id, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, player_id) do
    # Send the first ping asynchronously
    send(self(), :send_ping)
    {:noreply, player_id}
  end

  @impl true
  def handle_info(:send_ping, player_id) do
    Logger.warning("PING for player #{player_id}")

    # Call private method to send the ping to the player
    ClientUtils.send_to_player(player_id, Packets.ping())

    # Schedule the next ping
    Process.send_after(self(), :send_ping, @period_in_millis)

    {:noreply, player_id}
  end
end