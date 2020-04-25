defmodule Quarto.User do
  @moduledoc false
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
    field(:photo, :string)
    has_one(:profile, Quarto.Profile)
    timestamps()
  end
end

defmodule Quarto.Post do
  @moduledoc false
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
    field(:published_at, :utc_datetime)
    field(:position, :integer)

    belongs_to(:user, Quarto.User)

    timestamps()
  end
end
