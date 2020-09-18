Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

# Application.put_env(:logger, :console, level: :warn)

# Load up the repository, start it, and run migrations

_ = Ecto.Adapters.Postgres.storage_down(Quarto.Repo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Quarto.Repo.config())
{:ok, _} = Quarto.Repo.start_link()
:ok = Ecto.Migrator.up(Quarto.Repo, 0, Quarto.TestMigration, log: false)

Ecto.Adapters.SQL.Sandbox.mode(Quarto.Repo, :manual)

ExUnit.start(timeout: 120_000)
# {:ok, _} = Dataloader.TestRepo.start_link()
# Ecto.Adapters.SQL.Sandbox.mode(Dataloader.TestRepo, :manual)
