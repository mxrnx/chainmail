defmodule Server do
  require Logger
  @port 25565
  
  def start(_, _) do
    pid = spawn(fn -> start() end)

    {:ok, pid}
  end
  
  def start() do
    # Set up supervisor
    children = [
      %{
        id: Listener,
        start: {Listener, :start, [@port, self()]}
      },
      Players,
      Level
    ]

    {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one, auto_shutdown: :never)
    
    main(supervisor_pid)
  end
  
  def main(supervisor_id) do
    Logger.info("Entering main loop")
    receive do
      {:shutdown} ->
        Logger.info("Shutting down server")
        System.stop(0)
      {:spawn_player, player_id, packet} ->
        Logger.info("Broadcasting player spawn")
        Enum.map(Enum.reject(Players.all(), &(&1.id == player_id)), & send(&1.sender_pid, packet))
      {:set_block, packet} ->
        Logger.info("Received set block message")
        Enum.map(Players.all(), & send(&1.sender_pid, packet))
      _ ->
        Logger.info("Received unknown message")
    end
    main(supervisor_id)
  end
end
