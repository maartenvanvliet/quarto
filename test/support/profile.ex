defmodule Quarto.Profile do
  @moduledoc false
  use Ecto.Schema

  schema "profiles" do
    field(:title, :string)
    belongs_to(:user, Quarto.User)
    timestamps()
  end
end
