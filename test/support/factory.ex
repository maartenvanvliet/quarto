defmodule Quarto.Factory do
  @moduledoc false

  def build(:post) do
    %Quarto.Post{}
  end

  def build(:profile) do
    %Quarto.Profile{}
  end

  def build(:user) do
    %Quarto.User{}
  end

  def build(name) do
    raise name
  end

  def build(factory_name, attributes) do
    factory_name |> build() |> struct(attributes)
  end

  def insert(factory_name, attributes \\ []) do
    Quarto.Repo.insert!(build(factory_name, attributes))
  end
end
