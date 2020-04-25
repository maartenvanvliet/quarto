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

  It's a helper function for taking the (nested) fields used for ordering and constructing the
  list that can be passed to the cursor encoder.

  In addition to this it's also possible to pass in the queryable used to generate the original query and cursors
  and derive the (nested) fields from that.

  Building the opaque cursor from the list `cursor_for_entry/3` generates can be done by e.g. the `Quarto.Cursor.Base64` module
  or any other module that implements the `Quarto.Cursor` behaviour.

      iex> Quarto.cursor_for_entry(%User{id: 1}, :id)
      [1]
      iex> Quarto.cursor_for_entry(%User{id: 1}, [:id, :name])
      [1, nil]
      iex> Quarto.cursor_for_entry(%User{id: 1, profile: %Profile{title: "A profile"}}, {:profile, :title})
      ["A profile"]
      iex> Quarto.cursor_for_entry(%User{id: 1, profile: %Profile{title: "A profile"}}, [[:profile, :title], :id])
      ["A profile", 1]
      iex> Quarto.cursor_for_entry(%User{id: 1, profile: %Profile{title: "A profile"}}, [:id, {:profile, :title}])
      [1, "A profile"]
      iex> cursor = Quarto.cursor_for_entry(%Post{id: 2, user: %User{id: 1, profile: %Profile{title: "A profile"}}}, {:user, {:profile, :title}})
      ["A profile"]
      iex> Quarto.Cursor.Base64.encode!(cursor)
      "g2wAAAABbQAAAAlBIHByb2ZpbGVq"

      iex> queryable = Post |> order_by({:desc, :position})
      iex> Quarto.cursor_for_entry(%Post{id: 2, position: 3}, queryable)
      [3]

      iex> queryable = Quarto.Post
      ...> |> join(:left, [p], u in assoc(p, :user), as: :user)
      ...> |> preload([p, u], user: u)
      ...> |> order_by([p, u], desc: u.name)
      ...> |> order_by({:desc, :position})
      iex> cursor = Quarto.cursor_for_entry(%Post{id: 2, position: 3, user: %User{name: "A. Hamilton"}}, queryable)
      ["A. Hamilton", 3]
      iex> Quarto.Cursor.Base64.encode!(cursor)
      "g2wAAAACbQAAAAtBLiBIYW1pbHRvbmEDag=="
  """
  def cursor_for_entry(entry, queryable, opts \\ [])

  def cursor_for_entry(entry, %Ecto.Query{} = queryable, opts) do
    %{cursor_builder: {m, f, _}} = config = Quarto.Config.new([queryable: queryable] ++ opts)

    Kernel.apply(m, f, [entry, config])
  end

  def cursor_for_entry(entry, cursor_fields, _opts)
      when is_list(cursor_fields) do
    Enum.map(cursor_fields, &cursor_for_entry_path(entry, &1))
  end

  def cursor_for_entry(entry, cursor_fields, opts) do
    cursor_for_entry(entry, [cursor_fields], opts)
  end

  defp cursor_for_entry_path(entry, field) when is_atom(field) do
    Map.get(entry, field)
  end

  defp cursor_for_entry_path(entry, {field, key}) do
    path = to_list({field, key})
    cursor_for_entry_path(entry, path)
  end

  defp cursor_for_entry_path(entry, path) when is_list(path) do
    path = Enum.map(path, &Access.key/1)
    get_in(entry, path)
  end

  defp to_list(nest) when is_tuple(nest) do
    case Tuple.to_list(nest) do
      [field, {a, b}] -> [field | to_list({a, b})]
      [field, value] -> [field, value]
    end
  end

  defp build_cursor_value(entry, %{cursor_builder: {m, f, _}} = config) do
    Kernel.apply(m, f, [entry, config]) |> config.cursor.encode!(config)
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
      build_cursor_value(first, config)
    else
      nil
    end
  end

  defp last_or_nil(entries, config) do
    if last = List.last(entries) do
      build_cursor_value(last, config)
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
