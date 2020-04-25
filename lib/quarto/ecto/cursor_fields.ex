defmodule Quarto.Ecto.CursorFields do
  @moduledoc """
  Derive the cursor fields from a given queryable

  """
  @doc """
  build/2 accepts an Ecto.Query and inspects the Ecto AST to retrieve
  the fields the query will order by. These will be used to create the
  cursor.
  """
  @spec build(queryable :: Ecto.Query.t(), config :: Keyword.t()) :: [any]
  def build(%Ecto.Query{order_bys: order_bys} = queryable, _config) do
    Enum.map(order_bys, fn %Ecto.Query.QueryExpr{expr: expr} ->
      case expr do
        [{direction, {{:., [], [{:&, [], [position]}, field]}, [], []}}] ->
          {field, {position, direction}}

        [{_direction, {:fragment, [], _ast}}] ->
          raise ArgumentError, "Fragments not supported currently, got: #{inspect(queryable)}"

        [{_direction, _unsupported}] ->
          raise ArgumentError,
                "Unsupported clause passed into order by expr #{inspect(queryable)}"
      end
    end)
  end

  def build(unknown, _config) do
    raise ArgumentError, "Expecting an `%Ecto.Query{}` struct, got: #{inspect(unknown)}"
  end
end
