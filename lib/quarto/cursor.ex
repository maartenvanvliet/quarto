defmodule Quarto.Cursor do
  @moduledoc """
  Behaviour for custom encoding of cursor values.

  Used if you want finer control over how the values are encoded or decoded.
  Could be used to ensure the cursor are signed or validate cursors at your
  application boundaries.


  ```elixir
  defmodule CustomCursor do
    @behaviour Quarto.Cursor

    ...
  end

  Quarto.Post
  |> order_by(desc: :id)
  |> Repo.paginate(cursor: CustomCursor)
  ```

  """

  @doc """
  Decodes a cursor binary.

  Returns an :ok tuple if it was able to decode the cursor, or else an :error tuple
  """
  @callback decode(encoded_cursor :: nil | binary, opts :: list()) :: {:ok, term} | {:error, any}

  @doc """
  Decodes a cursor binary.

  Returns the cursor or raises when it fails to decode
  """
  @callback decode!(encoded_cursor :: nil | binary, opts :: list()) :: term
  @doc """
  Encodes an erlang term

  Returns an :ok tuple if it was able to encode the cursor, or else an :error tuple
  """
  @callback encode(decoded_cursor :: term, opts :: list()) :: {:ok, binary} | {:error, any}
  @doc """
  Encodes an erlang term.

  Returns the cursor or raises when it fails to encodes
  """
  @callback encode!(decoded_cursor :: term, opts :: list()) :: binary
end
