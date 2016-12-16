defmodule PythonCalls.Client do
  use Riffed.Client,
  structs: PythonCalls.Models,
  client_opts: [
    host: "localhost",
    port: 9090,
    retries: 3,
    framed: true
  ],
  service: :geo_service_thrift,
  import: [:blockInZone]
end