defmodule Quarto.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using _opts do
    quote do
      alias Quarto.Repo

      import Ecto
      import Ecto.Query
      import Quarto.Factory
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Quarto.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Quarto.Repo, {:shared, self()})
    end

    :ok
  end
end
