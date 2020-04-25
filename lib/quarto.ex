defmodule Quarto do
  @external_resource "./README.md"
  @moduledoc """
  #{File.read!(@external_resource) |> String.split("---", parts: 2) |> List.last()}
  """

  defmacro __using__(opts) do
    quote do
      @defaults unquote(opts)

      def paginate(queryable, opts \\ [], repo_opts \\ []) do
        opts = Keyword.merge(@defaults, opts)

        Quarto.paginate(queryable, opts, __MODULE__, repo_opts)
      end
    end
  end

  @spec paginate(Ecto.Query.t(), nil | maybe_improper_list, Ecto.Repo.t(), Keyword.t()) ::
          Quarto.Page.t()
  @doc """
  Paginate/4

  Fetches all the results matching the query within the cursors.

  Options

    * `:after` - Fetch the records after this cursor.
    * `:before` - Fetch the records before this cursor.
    * `:coalesce` - Function that receives the field
    * `:cursor` - Module to use for encoding/decoding the cursor
    * `:cursor_fields` - Module to use for building the cursor from a record
    * `:include_total_count` - Set this to true to return the total number of records matching the query. Note that this number will be capped by :total_count_limit. Defaults to false.
    * `:total_count_primary_key_field` - Running count queries on specified column of the table
    * `:limit` - Limits the number of records returned per page. Note that this number will be capped by :maximum_limit. Defaults to `50`.
    * `:maximum_limit` - Sets a maximum cap for :limit. This option can be useful when :limit is set dynamically (e.g from a URL param set by a user) but you still want to enfore a maximum. Defaults to 500.
    * `:total_count_limit` - Running count queries on tables with a large number of records is expensive so it is capped by default. Can be set to `:infinity` in order to count all the records. Defaults to 10,000.

  Repo options

  This will be passed directly to Ecto.Repo.all/2, as such any option supported by this function can be used here.
  """
  def paginate(queryable, opts, repo, repo_opts \\ []) do
    config = Quarto.Config.new([queryable: queryable] ++ opts)

    sorted_entries = entries(queryable, config, repo, repo_opts)
    paginated_entries = paginate_entries(sorted_entries, config)

    {total_count, total_count_cap_exceeded} =
      Quarto.Ecto.QueryTotal.total_count(queryable, config, repo, repo_opts)

    %Quarto.Page{
      entries: paginated_entries,
      metadata: %Quarto.Page.Metadata{
        after: after_cursor(paginated_entries, sorted_entries, config),
        before: before_cursor(paginated_entries, sorted_entries, config),
        limit: config.limit,
        total_count: total_count,
        total_count_cap_exceeded: total_count_cap_exceeded
      }
    }
  end

  @doc """
  Build the cursor for a given entry

  See also `Quarto.CursorValue`
  """
  @spec cursor_for_entry(map, Quarto.Config.t()) :: any
  def cursor_for_entry(entry, config) do
    build_cursor_value(entry, config) |> config.cursor.encode!(config)
  end

  defp build_cursor_value(entry, %{cursor_builder: {m, f, _}} = config) do
    Kernel.apply(m, f, [entry, config])
  end

  defp after_cursor([], [], _config), do: nil

  defp after_cursor(paginated_entries, _sorted_entries, %{before: c_before} = config)
       when not is_nil(c_before) do
    last_or_nil(paginated_entries, config)
  end

  defp after_cursor(paginated_entries, sorted_entries, config) do
    if last_page?(sorted_entries, config) do
      nil
    else
      last_or_nil(paginated_entries, config)
    end
  end

  defp before_cursor([], [], _config), do: nil

  defp before_cursor(_paginated_entries, _sorted_entries, %{after: nil, before: nil}),
    do: nil

  defp before_cursor(paginated_entries, _sorted_entries, %{after: c_after} = config)
       when not is_nil(c_after) do
    first_or_nil(paginated_entries, config)
  end

  defp before_cursor(paginated_entries, sorted_entries, config) do
    if first_page?(sorted_entries, config) do
      nil
    else
      first_or_nil(paginated_entries, config)
    end
  end

  defp first_or_nil(entries, config) do
    if first = List.first(entries) do
      cursor_for_entry(first, config)
    else
      nil
    end
  end

  defp last_or_nil(entries, config) do
    if last = List.last(entries) do
      cursor_for_entry(last, config)
    else
      nil
    end
  end

  defp first_page?(sorted_entries, %{limit: limit}) do
    Enum.count(sorted_entries) <= limit
  end

  defp last_page?(sorted_entries, %{limit: limit}) do
    Enum.count(sorted_entries) <= limit
  end

  defp entries(queryable, config, repo, repo_opts) do
    queryable
    |> Quarto.Ecto.Query.paginate(config)
    |> repo.all(repo_opts)
  end

  defp paginate_entries(sorted_entries, %{after: nil, before: before, limit: limit})
       when not is_nil(before) do
    sorted_entries
    |> Enum.take(limit)
    |> Enum.reverse()
  end

  defp paginate_entries(sorted_entries, %{limit: limit}) do
    Enum.take(sorted_entries, limit)
  end
end
