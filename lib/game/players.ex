defmodule Players do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def add(name, client_sender_id) do
    Agent.get_and_update(__MODULE__, fn players ->
      if Enum.any?(players, &(&1.name == name)) do
        {nil, players} # return nil on name already in use
      else
        id = next_id(players)
        new_player = %Player{name: name, id: id, client_sender_id: client_sender_id}
        {id, [new_player | players]}
      end
    end)
  end

  def get(id) do
    Agent.get(__MODULE__, fn players -> Enum.find(players, &(&1.id == id)) end)
  end

  def remove(id) do
    Agent.update(__MODULE__, fn players -> Enum.reject(players, &(&1.id == id)) end)
  end

  def all() do
    Agent.get(__MODULE__, & &1)
  end

  defp next_id(players) do
    next_id(1, Enum.map(players, & &1.id))
  end

  defp next_id(id, ids) do
    if !Enum.any?(ids, & &1 == id) do
      id
    else
      next_id(id + 1, ids)
    end
  end
end
