import Config

config :logger, :console,
       format: "[$level] $message $metadata\n",
       metadata: [:player_id, :name, :packet, :reason, :port],
       level: :info
