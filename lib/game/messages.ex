defmodule Messages do
  def player_join(player_name) do
    "&6#{player_name}&f joined the game."
  end

  def player_leave(player_name) do
    "&6#{player_name}&f left the game."
  end

  def player_message(player_name, message) do
    "<#{player_name}> #{sanitize(message)}"
  end

  defp sanitize(message) do
    String.trim_trailing(message, "&") # Messages ending with an ampersand crash vanilla clients
  end
end
