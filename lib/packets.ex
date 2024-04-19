defmodule Packets do
  require Level
  
  def server_identification(name, motd, mod?) do
    mod_byte = if mod?, do: 0x64, else: 0
    << 0, 7 >> <> pad_string(name) <> pad_string(motd) <> <<mod_byte>>
  end
  
  def ping() do
    << 1 >>
  end
  
  def level_initialize() do
    << 2 >>
  end
  
  def level_data_chunk(chunk) do
    chunk_size = length(chunk)
    << 3 >> <>  ProtocolTypes.short(chunk_size) <> pad_binary(to_binary(chunk), 1024) <> << 1 >>
  end
  
  defp pad_binary(data, pad) do
    actualpad = pad - byte_size(data)
    if actualpad > 0 do
      << data::binary, 0::actualpad*8 >>
    else
      data
    end
  end
  
  defp to_binary([head]) do
    << head::8 >>
  end
  
  defp to_binary([head | tail]) do
    << head::8 >> <> to_binary(tail)
  end
  
  def level_finalize do
    << 4 >> <> ProtocolTypes.short(Level.size_x) <> ProtocolTypes.short(Level.size_y) <> ProtocolTypes.short(Level.size_z) 
  end
  
  def spawn_player(id \\ 255) do
    << 7, id>> <> ProtocolTypes.short(320) <> ProtocolTypes.short(371) <> ProtocolTypes.short(2048) <> << 0, 0 >>
  end
  
  defp pad_string(string) do
    if byte_size(string) > 64 do
      String.slice(string, 0..63)
    else
      String.pad_trailing(string, 64, " ")
    end
  end
end