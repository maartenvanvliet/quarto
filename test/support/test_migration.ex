defmodule Quarto.TestMigration do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:comments) do
      add(:body, :text)
      add(:post_id, :integer)
      timestamps()
    end

    create table(:posts) do
      add(:title, :text)
      add(:position, :integer)
      add(:published_at, :utc_datetime)
      add(:user_id, :integer)
      timestamps()
    end

    create table(:profiles) do
      add(:title, :text)
      add(:user_id, :integer)
      timestamps()
    end

    create table(:users) do
      add(:name, :text)
      add(:photo, :text)
      timestamps()
    end
  end
end
