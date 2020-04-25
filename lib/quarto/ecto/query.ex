defmodule Quarto.Ecto.Query do
  @moduledoc false
  import Ecto.Query

  def paginate(queryable, config) do
    queryable
    |> maybe_where(config)
    |> limit(^query_limit(config))
  end

  defp query_limit(%{limit: limit}) do
    limit + 1
  end

  defp maybe_where(queryable, %{after: nil, before: nil} = config) do
    queryable |> order_by_coalescing(config)
  end

  defp maybe_where(queryable, %{after: after_c, before: nil} = config) do
    queryable
    |> filter_values(config, after_c, :after)
    |> order_by_coalescing(config)
  end

  defp maybe_where(queryable, %{after: nil, before: before} = config) do
    queryable
    |> filter_values(config, before, :before)
    |> order_by_coalescing(config)
    |> reverse_order
  end

  # Applying two cursors at the same time is not tested in unit tests
  defp maybe_where(queryable, %{after: after_c, before: before} = config) do
    queryable
    |> filter_values(config, before, :before)
    |> filter_values(config, after_c, :after)
    |> order_by_coalescing(config)
  end

  defp order_by_coalescing(queryable, config) do
    coalesced_order_bys =
      config.cursor_fields
      |> Enum.map(fn {field, {position, order}} ->
        # nil is passed as value so the coalescing function will cast it to a high/low value
        coalesce_value = config.coalesce.(field, position, nil)

        dynamic = dynamic([{q, position}], coalesce(field(q, ^field), ^coalesce_value))

        {order, dynamic}
      end)

    queryable
    |> Ecto.Query.exclude(:order_by)
    |> order_by(^coalesced_order_bys)
  end

  defp filter_values(queryable, %{cursor_fields: fields, coalesce: coalesce}, values, direction) do
    {positions, orders} = Keyword.values(fields) |> Enum.unzip()

    options = Enum.zip([values, positions, orders])

    sorts =
      fields
      |> Keyword.keys()
      |> Enum.zip(options)

    {dynamic_sorts, _} =
      Enum.reduce(sorts, {true, 0}, fn
        {field, {value, position, order}}, {dynamic_sorts, i} ->
          dynamic = true

          coalesce_value = coalesce.(field, position, value)

          dynamic =
            get_operator(order, direction)
            |> build_cursor_where(position, field, value, coalesce_value, dynamic)

          dynamic =
            sorts
            |> Enum.take(i)
            |> Enum.reduce(dynamic, fn {field, {value, position, _order}}, dynamic ->
              coalesce_value = coalesce.(field, position, value)

              build_cursor_where(:prev, position, field, value, coalesce_value, dynamic)
            end)

          dynamic =
            if i == 0 do
              dynamic([{q, position}], ^dynamic and ^dynamic_sorts)
            else
              dynamic([{q, position}], ^dynamic or ^dynamic_sorts)
            end

          {dynamic, i + 1}
      end)

    where(queryable, [q], ^dynamic_sorts)
  end

  defp build_cursor_where(:gt, position, field, nil, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) > ^coalesce_value and ^dynamic
    )
  end

  defp build_cursor_where(:gt, position, field, value, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) > ^value and ^dynamic
    )
  end

  defp build_cursor_where(:lt, position, field, nil, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) < ^coalesce_value and ^dynamic
    )
  end

  defp build_cursor_where(:lt, position, field, value, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) < ^value and ^dynamic
    )
  end

  defp build_cursor_where(:prev, position, field, nil, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) == ^coalesce_value and ^dynamic
    )
  end

  defp build_cursor_where(:prev, position, field, value, coalesce_value, dynamic)
       when is_atom(field) do
    dynamic(
      [{q, position}],
      coalesce(field(q, ^field), ^coalesce_value) == ^value and ^dynamic
    )
  end

  defp get_operator(:asc, :before), do: :lt
  defp get_operator(:asc_nulls_first, :before), do: :lt
  defp get_operator(:asc_nulls_last, :before), do: :lt

  defp get_operator(:asc, :after), do: :gt
  defp get_operator(:asc_nulls_first, :after), do: :gt
  defp get_operator(:asc_nulls_last, :after), do: :gt

  defp get_operator(:desc, :before), do: :gt
  defp get_operator(:desc_nulls_first, :before), do: :gt
  defp get_operator(:desc_nulls_last, :before), do: :gt

  defp get_operator(:desc, :after), do: :lt
  defp get_operator(:desc_nulls_first, :after), do: :lt
  defp get_operator(:desc_nulls_last, :after), do: :lt

  defp get_operator(direction, _),
    do: raise("Invalid sorting value :#{direction}, please use either :asc or :desc")
end
