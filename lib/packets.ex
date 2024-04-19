defmodule Packets do
  def server_identification(name, motd, mod?) do
    mod_byte = if mod?, do: 0x64, else: 0
    << 0, 7 >> <> pad_string(name) <> pad_string(motd) <> <<mod_byte>>
  end
  
  def level_initialize() do
    << 2 >>
  end
  
  defp pad_string(string) do
    if byte_size(string) > 64 do
      String.slice(string, 0..63)
    else
      String.pad_trailing(string, 64, " ")
    end
  end
end