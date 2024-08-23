defmodule Generators do
  require Level

  def testworld() do
    Enum.flat_map(1..Level.size_y, fn y ->
      Enum.flat_map(1..Level.size_z, fn _z ->
        Enum.map(1..Level.size_x, fn _x ->
          set_testworld_block(y)
        end)
      end)
    end)
  end

  # PRIVATE

  defp set_testworld_block(y) do
    case y do
      n when n < 26 -> 1
      n when n < 32 -> 3
      32 -> 2
      _ -> 0
    end
  end
end
