defprotocol Quarto.Cursor.Encode do
  @moduledoc """
  Protocol for encoding individual cursor values.

  E.g. some values are overly lengthy when encoding with the default way,
  implementing a custom protocol can cut that down

  ```
  defimpl Quarto.Cursor.Encode, for: DateTime do
    def convert(term), do: {"dt", DateTime.to_unix(term, :microsecond)}
  end

  defimpl Quarto.Cursor.Decode, for: Tuple do
    def convert({"dt", unix_timestamp}), do: DateTime.from_unix!(unix_timestamp, :microsecond)
  end
  ```

  See https://github.com/duffelhq/paginator/pull/62 for a helpful issue

  """
  @fallback_to_any true

  @doc """
  Converts the term to a single cursor value

  """
  def convert(term)
end

defimpl Quarto.Cursor.Encode, for: Any do
  def convert(term), do: term
end
