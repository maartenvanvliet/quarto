defmodule Quarto.Ecto.QueryTotal do
  @moduledoc false
  import Ecto.Query

  @spec total_count(queryable :: Ecto.Query.t(), Quarto.Config.t(), Ecto.Repo.t(), keyword()) ::
          {integer, false | nil | true}
  def total_count(_queryable, %{include_total_count: false}, _repo, _repo_opts),
    do: {nil, nil}

  def total_count(
        queryable,
        %{
          total_count_limit: total_count_limit,
          total_count_primary_key_field: total_count_primary_key_field
        },
        repo,
        repo_opts
      ) do
    result =
      queryable
      |> exclude(:preload)
      |> exclude(:select)
      |> exclude(:order_by)
      |> maybe_total_limit(total_count_limit)
      |> select([e], struct(e, [total_count_primary_key_field]))
      |> subquery
      |> select(count("*"))
      |> repo.one(repo_opts)

    cap_exceeded =
      case total_count_limit do
        :infinity -> false
        _ -> result > total_count_limit
      end

    {Enum.min([result, total_count_limit]), cap_exceeded}
  end

  defp maybe_total_limit(queryable, :infinity) do
    queryable
  end

  defp maybe_total_limit(queryable, total_count_limit) do
    queryable
    |> limit(^(total_count_limit + 1))
  end
end
