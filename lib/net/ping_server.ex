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
    {:ok, client_sender_id, {:continue, :init}}
  end

  # TODO: can we do without this?
  @impl true
  def handle_continue(:init, client_sender_id) do
    # Send the first ping asynchronously
    send(self(), :send_ping)
    {:noreply, client_sender_id}
  end

  @impl true
  @doc """
    Instruct the client sender to ping the player. Note that the point of this is that if during sending it turns out 
    the pipe was broken at some point, the player is despawned.
  """
  def handle_info(:send_ping, client_sender_id) do
    send(client_sender_id, :send_ping)
    Process.send_after(self(), :send_ping, @period_in_millis)
    {:noreply, client_sender_id}
  end
end