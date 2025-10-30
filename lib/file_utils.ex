defmodule FileUtils do
	def export_level() do
		{:ok, file} = File.open("world.gzip", [:write, :append])
		IO.binwrite(file, Level.to_gzip())
		File.close(file)
	end
end