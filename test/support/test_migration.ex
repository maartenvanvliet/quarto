defmodule Quarto.TestMigration do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:comments) do
      add(:body, :string)
      add(:post_id, :integer)
      timestamps()
    end

    create table(:posts) do
      add(:title, :string)
      add(:position, :integer)
      add(:published_at, :utc_datetime)
      add(:user_id, :integer)
      timestamps()
    end

    create table(:profiles) do
      add(:title, :string)
      add(:user_id, :integer)
      timestamps()
    end

    create table(:users) do
      add(:name, :string)
      add(:photo, :string)
      timestamps()
    end
  end
end
