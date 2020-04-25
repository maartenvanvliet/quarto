defmodule Quarto.Page do
  @moduledoc """
  Defines a page.
  ## Fields
  * `entries` - a list entries contained in this page.
  * `metadata` - metadata attached to this page (see `Quarto.Page.Metadata`)
  """

  @type t :: %__MODULE__{
          entries: [any()] | [],
          metadata: Quarto.Page.Metadata.t()
        }

  defstruct [:metadata, :entries]
end
