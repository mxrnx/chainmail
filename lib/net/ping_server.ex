defmodule PingServer do
  require Logger
  use GenServer

  @period_in_millis 5000

  # Public API to start the GenServer
  def start_link(client_sender_id) do
    GenServer.start_link(__MODULE__, client_sender_id)
  end

  @impl true
  def init(client_sender_id) do
    Logger.debug("Starting PingServer")
    schedule_ping()
    {:ok, client_sender_id}
  end

  @impl true
  @doc """
    Instruct the client sender to ping the player. Note that the point of this is that if during sending it turns out 
    the pipe was broken at some point, the player is despawned.
  """
  def handle_info(:send_ping, client_sender_id) do
    GenServer.cast(client_sender_id, :send_ping)
    schedule_ping()
    {:noreply, client_sender_id}
  end
  
  defp schedule_ping() do
    Process.send_after(self(), :send_ping, @period_in_millis)
  end
end