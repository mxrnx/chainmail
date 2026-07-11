defmodule Server do
  use Application
  require Logger

  @port 25565
  @password "chunky bacon"

  def start(_type, _args) do
    Logger.notice("Welcome to chainmail.")

    children = [
      %{
        id: ConnectionListener,
        start: {ConnectionListener, :start, [@port, self()]}
      },
      Players,
      Level
    ]

    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def main() do
    Logger.debug("Entering main loop.")

    receive do
      {:shutdown} ->
        Logger.notice("Shutting down server.")
        # TODO: save level
        # TODO: broadcast shutdown to clients
        System.stop(0)
    end

    main()
  end

  # TODO: move elsewhere
  def correct_password?(password) do
    !@password || @password == String.trim_trailing(password)
  end
end
