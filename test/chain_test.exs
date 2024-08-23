defmodule ChainTest do
  use ExUnit.Case
  doctest Chainmail

  test "greets the world" do
    assert Chainmail.hello() == :world
  end
end
