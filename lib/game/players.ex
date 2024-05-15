defmodule Players do
  use Agent
  
  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end
  
  def add(username, sender_pid) do
    id = next_id()
    Agent.update(__MODULE__, fn players -> [%Player{name: username, id: id, sender_pid: sender_pid} | players] end)
    id
  end
  
  def remove(id) do
    Agent.update(__MODULE__, fn players -> Enum.reject(players, &(&1.id == id)) end)
  end

  def all() do
    Agent.get(__MODULE__, & &1)
  end

  defp next_id do
    next_id(1, Agent.get(__MODULE__, fn players -> Enum.map(players, &(&1.id)) end))
  end
  
  defp next_id(id, ids) do
    if !Enum.any?(ids, & &1 == id) do
      id
    else
      next_id(id + 1, ids)
    end
  end
end
