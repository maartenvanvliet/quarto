defmodule Quarto.CursorValue do
  @moduledoc """
  Module called to build the cursor

  Receives an entry, this will most likely be an Ecto struct.
  From the config it will derive the cursor fields and will fetch the value
  of those fields from the struct. It tries to chase down bindings to see if
  it can find the cursor field on related records.
  """
  @spec build(any, Quarto.Config.t()) :: [any]
  def build(entry, %{cursor_fields: cursor_fields, queryable: queryable}) do
    Enum.map(cursor_fields, &get_cursor_value(&1, entry, queryable))
  end

  defp get_cursor_value({field, {0, _}}, entry, _queryable) do
    Map.get(entry, field)
  end

  defp get_cursor_value({field, {position, _}}, entry, queryable) do
    case chase_binding(queryable, position) do
      nil ->
        raise "Could not find a binding in position #{position} in assocs #{inspect(queryable.assocs)} or in aliases #{inspect(queryable.aliases)}"

      key ->
        key = key |> Enum.reverse() |> Enum.map(&Access.key/1)
        schema = get_in(entry, key)
        Map.get(schema, field)
    end
  end

  defp chase_binding(queryable, position) do
    case find_alias_binding(queryable, position) do
      nil -> find_assoc(queryable.assocs, position)
      alias_binding -> alias_binding
    end
  end

  # First check aliases to see if matching binding
  defp find_alias_binding(queryable, position) do
    Enum.find_value(queryable.aliases, fn
      {name, ^position} -> [name]
      _ -> false
    end)
  end

  # the assocs on the queryable can also be inspected
  # for a binding in the right position
  defp find_assoc(assocs, position) do
    Enum.find_value(assocs, fn
      {key, {^position, _}} -> [key]
      {key, {_, assocs}} -> find_assoc(assocs, position) ++ [key]
      _ -> false
    end)
  end
end
