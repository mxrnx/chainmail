defmodule Messages do
  def player_join(player_name) do
    "&e* #{player_name} joined the game."
  end

  def player_message(player_name, message) do
    "<#{player_name}> #{sanitize(message)}"
  end

  defp sanitize(message) do
    String.trim_trailing(message, "&") # Messages ending with an ampersand crash vanilla clients
  end
end
