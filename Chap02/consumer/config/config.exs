use Mix.Config

config :logger,
  backends: [:console, {LoggerFileBackend, :info_log}]

config :logger, :info_log,
  path: "log/info.log",
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:module, :function, :line],
  level: :info
