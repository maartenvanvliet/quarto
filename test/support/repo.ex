defmodule Quarto.Repo do
  use Ecto.Repo,
    otp_app: :quarto,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    test_config = [
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "postgres",
      database: "quarto_test",
      hostname: "localhost",
      port: "5432"
    ]

    {:ok, Keyword.merge(config, test_config)}
  end

  use Quarto
end
