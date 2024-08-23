defmodule Server do
  require Logger
  @port 25565
  @password "chunky bacon"
  
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

    {:ok, _supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one, auto_shutdown: :never)
    
    main()
  end
  
  def main() do
    Logger.debug("Entering main loop")
    receive do
      {:shutdown} ->
        Logger.notice("Shutting down server.")
        System.stop(0)
    end
    main()
  end

  def correct_password?(password) do
    !@password || @password == String.trim_trailing(password)
  end
end
