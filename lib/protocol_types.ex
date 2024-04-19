defmodule ProtocolTypes do
  def short(number) do
    << number::integer-big-signed-size(16) >>
  end
  
  def int(number) do
    << number::integer-big-size(32) >>
  end
end