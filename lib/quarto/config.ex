defmodule Quarto.Config do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [
    :after,
    :before,
    :coalesce,
    :cursor_builder,
    :cursor_fields,
    :cursor,
    :custom_options,
    :transform,
    :include_total_count,
    :include_entries,
    :limit,
    :maximum_limit,
    :queryable,
    :total_count_limit,
    :total_count_primary_key_field
  ]

  @default_total_count_primary_key_field :id
  @default_limit 50
  @minimum_limit 1
  @maximum_limit 500
  @default_total_count_limit 10_000

  @spec new(maybe_improper_list) :: Quarto.Config.t()
  def new(opts \\ []) do
    queryable = opts[:queryable]
    codec = opts[:cursor] || Quarto.Cursor.Base64
    cursor_fields = opts[:cursor_fields] || Quarto.Ecto.CursorFields

    %__MODULE__{
      cursor: codec,
      custom_options: opts[:custom_options],
      before: decode(opts[:before], codec),
      after: decode(opts[:after], codec),
      queryable: queryable,
      coalesce: opts[:coalesce] || fn _field, _position_, _value -> nil end,
      cursor_builder: {Quarto.CursorValue, :build, []},
      cursor_fields: cursor_fields.build(queryable, opts),
      include_entries: Keyword.get(opts, :include_entries, true),
      include_total_count: opts[:include_total_count] || false,
      total_count_primary_key_field:
        opts[:total_count_primary_key_field] || @default_total_count_primary_key_field,
      limit: limit(opts),
      total_count_limit: opts[:total_count_limit] || @default_total_count_limit
    }
  end

  defp decode(list, _codec) when is_list(list) do
    list
  end

  defp decode(encoded_cursor, codec) do
    codec.decode!(encoded_cursor)
  end

  defp limit(opts) do
    max = max(opts[:limit] || @default_limit, @minimum_limit)
    min(max, opts[:maximum_limit] || @maximum_limit)
  end
end
