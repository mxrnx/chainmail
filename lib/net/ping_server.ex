defmodule PingServer do
  require Logger
  use GenServer

  @period_in_millis 5000

  # Public API to start the GenServer
  def start_link(player_id) do
    GenServer.start_link(__MODULE__, player_id, name: __MODULE__)
  end

  @impl true
  def init(player_id) do
    Logger.debug("Starting PingServer")
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
    Logger.debug("PING player #{player_id}")

    # Try to ping the player. If during sending it turns out the pipe is broken, the player is despawned.
    # Next iteration the player will not be found, so we enter the rescue block and quietly end this server.
    case ClientUtils.send_to_player(player_id, Packets.ping()) do
      :ok ->
        Process.send_after(self(), :send_ping, @period_in_millis)
        {:noreply, player_id}
      :error ->
        Logger.debug("Player #{player_id} was already despawned when pinging.")
        {:stop, :normal, player_id}
    end

  end
end