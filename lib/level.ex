defmodule Level do
  use Agent
  require Logger
  @size_x 128
  @size_y 64
  @size_z 128
  
  defmacro size_x, do: @size_x
  defmacro size_y, do: @size_y
  defmacro size_z, do: @size_z
  
  def start_link(_) do
    blocks = Enum.map(1..(@size_x * @size_y * @size_z), fn _ -> 0 end)
    pid = Agent.start_link(fn -> blocks end, name: __MODULE__)
    spawn(generate_test_level())
    pid
  end
  
  def to_gzip() do
    Agent.get(__MODULE__, & &1)
      |> :binary.list_to_bin
      |> prepend_size
      |> :zlib.gzip
  end
  
  defp prepend_size(list) do
    <<0::8, 16::8, 0::8, 0::8, list :: binary>>
  end
  
  defp generate_test_level() do
    set_layer(0, 31, 49);
    set_layer(31, 32, 2);
    set_layer(32, 64, 0);
  end
  
  defp set_layer(min_y, max_y, block) do
    Enum.each(min_y..(max_y-1), fn y ->
      Enum.each(0..(@size_z-1), fn z ->
        Enum.each(0..(@size_x-1), fn x ->
          set_block(x, y, z, block)
        end)
      end) 
    end)
  end
  
  defp set_block(x, y, z, block) when x < @size_x and y < @size_y and z < @size_z do
    Agent.update(__MODULE__, & List.replace_at(&1, (y * @size_z + z) * @size_x + x, block))
  end
end