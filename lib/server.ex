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
      {Registry, keys: :unique, name: ClientSenders},
      Players
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
      _ ->
        Logger.info("Unknown")
        main(supervisor_id)
    end
  end
end
