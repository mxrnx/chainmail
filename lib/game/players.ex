defmodule Players do
  use Agent
  
  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end
  
  def add(name, socket) do
    if name_in_use?(name) do
      nil
    else
      id = next_id()
      Agent.update(__MODULE__, fn players -> [%Player{name: name, id: id, socket: socket} | players] end)
      id
    end
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
  
  def name_in_use?(name) do
    Agent.get(__MODULE__, fn players -> Enum.any?(players, &(&1.name == name)) end)
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
