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
    blocks = Generators.testworld()
    Logger.info("Generated world")
    Agent.start_link(fn -> blocks end, name: __MODULE__)
  end

  def to_gzip() do
    Agent.get(__MODULE__, & &1)
      |> :binary.list_to_bin
      |> prepend_size
      |> :zlib.gzip
  end

  def set_block(<<x::16>>, <<y::16>>, <<z::16>>, <<mode::8>>, <<block::8>>) 
      when x < @size_x and y < @size_y and z < @size_z do
    block_value =
      case mode do
        1 ->
          Logger.debug("Block #{block} set at (#{x}, #{y}, #{z})")
          block

        0 ->
          Logger.debug("Block destroyed at (#{x}, #{y}, #{z})")
          0
      end

    Agent.update(__MODULE__, fn blocks ->
      List.replace_at(blocks, (y * @size_z + z) * @size_x + x, block_value)
    end)

    block_value
  end

  defp prepend_size(list) do
    <<0::8, 16::8, 0::8, 0::8, list::binary>>
  end
end
