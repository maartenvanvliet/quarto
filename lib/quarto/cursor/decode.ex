defprotocol Quarto.Cursor.Decode do
  @fallback_to_any true

  @moduledoc """
  See `Quarto.Cursor.Encode`
  """
  @doc """
  Converts the binary to a single cursor term

  """
  def convert(binary)
end

defimpl Quarto.Cursor.Decode, for: Any do
  def convert(term), do: term
end
