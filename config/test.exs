import Config

config :logger, level: :info

config :stream_data,
  max_runs: if(System.get_env("CI"), do: 1_000, else: 50)
