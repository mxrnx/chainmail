defmodule Listener do
  require Logger

  # Internal
  def start(port, server_pid) do
    pid =
      spawn_link(fn ->
        case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true, packet: 0]) do
          {:ok, listen_socket} ->
            Logger.notice("Server started listening.", port: port)
            listen(listen_socket, server_pid)

          {:error, reason} ->
            Logger.error("Could not listen.", reason: reason, port: port)
            {:error, reason}
        end
      end)

    {:ok, pid}
  end

  defp listen(listen_socket, server_pid) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        Logger.debug("Client connecting...")
        spawn_link(fn -> Client.start(socket, server_pid) end)
        Logger.debug("Client connected!")
        listen(listen_socket, server_pid)

      {:error, reason} ->
        Logger.error("Could not connect with client", reason: reason)
        {:error, reason}
    end
  end
end
