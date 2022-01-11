defmodule QuartoTest do
  use Quarto.DataCase, async: true
  use ExUnitProperties
  alias Quarto.Cursor
  alias Quarto.Page
  alias Quarto.Page.Metadata

  alias Quarto.Post
  alias Quarto.User
  alias Quarto.Profile

  doctest Quarto
  setup :create_posts

  defmodule TestRepo do
    def all(queryable, opts \\ []) do
      send(self(), {:query, queryable})
      Quarto.Repo.all(queryable, opts)
    end
  end

  defmodule Run do
    defstruct [:direction, :fields, :posts, :limit, :title, :total_count_cap]
  end

  @opts [limit: 4]

  property "paginates forward" do
    check all(%{title: title} = run <- generate_run()) do
      expected_posts = sort_by_fields(run.posts, run.fields, run.direction)

      query =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user), as: :user)
        |> preload([p, u], user: u)
        |> where(title: ^title)
        |> build_order_by(run.fields, run.direction)

      first_page = Quarto.Repo.paginate(query, limit: run.limit)
      posts = rebuild_list_forward(query, first_page, limit: run.limit)

      assert to_ids(expected_posts) == to_ids(posts.entries)
      assert posts.metadata.after == nil

      cleanup!(title)
    end
  end

  property "paginates backward" do
    check all(%{title: title} = run <- generate_run(min_length: 1)) do
      {last_post, expected_posts} =
        sort_by_fields(run.posts, run.fields, run.direction)
        |> split_of_cursor_post

      before_cursor = run.fields |> cursor_values_from_fields(last_post) |> encode_cursor

      query =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user), as: :user)
        |> preload([p, u], user: u)
        |> where(title: ^title)
        |> build_order_by(run.fields, run.direction)

      first_page = Quarto.Repo.paginate(query, limit: run.limit, before: before_cursor)

      posts = rebuild_list_backward(query, first_page, limit: run.limit)

      assert to_ids(expected_posts) == to_ids(posts.entries)
      assert posts.metadata.before == nil

      cleanup!(title)
    end
  end

  property "has total count" do
    check all(%{title: title} = run <- generate_run()) do
      expected_posts = sort_by_fields(run.posts, run.fields, run.direction)

      query =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user), as: :user)
        |> preload([p, u], user: u)
        |> where(title: ^title)
        |> build_order_by(run.fields, run.direction)

      first_page = Quarto.Repo.paginate(query, limit: run.limit, include_total_count: true)
      posts = rebuild_list_forward(query, first_page, limit: run.limit, include_total_count: true)

      assert posts.metadata.total_count == length(expected_posts)

      cleanup!(title)
    end
  end

  describe "paginate descending with nil, 2 cursor fields" do
    test "paginates forward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, value ->
              case field do
                :title -> "Z"
                _ -> value
              end
            end
          ]

      page = posts_by_title_and_position(:desc) |> paginate(opts)
      assert to_ids(page.entries) == to_ids([p6, p5, p4, p3])
      assert page.metadata.after == encode_cursor([p3.title, p3.position])

      page = posts_by_title_and_position(:desc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p2, p12, p11, p10])
      assert page.metadata.after == encode_cursor([p10.title, p10.position])

      page = posts_by_title_and_position(:desc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p9, p8, p7, p1])
      assert page.metadata.after == nil
    end

    test "paginates backward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, value ->
              case field do
                :title -> "Z"
                _ -> value
              end
            end
          ]

      posts_by_title_and_position(:desc) |> Quarto.Repo.all()

      page =
        posts_by_title_and_position(:desc)
        |> paginate(opts ++ [before: encode_cursor([p1.title, p1.position])])

      assert to_ids(page.entries) == to_ids([p10, p9, p8, p7])
      assert page.metadata.before == encode_cursor([p10.title, p10.position])

      page =
        posts_by_title_and_position(:desc)
        |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p3, p2, p12, p11])
      assert page.metadata.before == encode_cursor([p3.title, p3.position])

      page =
        posts_by_title_and_position(:desc) |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p6, p5, p4])
      assert page.metadata.after == encode_cursor([p4.title, p4.position])

      assert page.metadata.before == nil
    end
  end

  describe "paginate ascending with nil, 2 cursor fields" do
    test "paginates forward, low COALESCE value", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, _value ->
              case field do
                :title -> "0"
                _ -> nil
              end
            end
          ]

      page = posts_by_title_and_position(:asc) |> paginate(opts)
      assert to_ids(page.entries) == to_ids([p2, p3, p4, p5])
      assert page.metadata.after == encode_cursor([p5.title, p5.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p6, p1, p7, p8])
      assert page.metadata.after == encode_cursor([p8.title, p8.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p9, p10, p11, p12])
      assert page.metadata.after == nil
    end

    test "paginates backward, low COALESCE value", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, value ->
              case field do
                :title -> "0"
                _ -> value
              end
            end
          ]

      page =
        posts_by_title_and_position(:asc)
        |> paginate(opts ++ [before: encode_cursor([p12.title, p12.position])])

      assert to_ids(page.entries) == to_ids([p8, p9, p10, p11])
      assert page.metadata.before == encode_cursor([p8.title, p8.position])

      page =
        posts_by_title_and_position(:asc)
        |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p5, p6, p1, p7])
      assert page.metadata.before == encode_cursor([p5.title, p5.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p2, p3, p4])
      assert page.metadata.after == encode_cursor([p4.title, p4.position])

      assert page.metadata.before == nil
    end

    test "paginates forward, high COALESCE value", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, value ->
              case field do
                :title -> "Z"
                _ -> value
              end
            end
          ]

      page = posts_by_title_and_position(:asc) |> paginate(opts)
      assert to_ids(page.entries) == to_ids([p1, p7, p8, p9])
      assert page.metadata.after == encode_cursor([p9.title, p9.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p10, p11, p12, p2])
      assert page.metadata.after == encode_cursor([p2.title, p2.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p3, p4, p5, p6])
      assert page.metadata.after == nil
    end

    test "paginates backward, high COALESCE value", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      opts =
        @opts ++
          [
            coalesce: fn field, _position, value ->
              case field do
                :title -> "Z"
                _ -> value
              end
            end
          ]

      page =
        posts_by_title_and_position(:asc)
        |> paginate(opts ++ [before: encode_cursor([p6.title, p6.position])])

      assert to_ids(page.entries) == to_ids([p2, p3, p4, p5])
      assert page.metadata.before == encode_cursor([p2.title, p2.position])

      page =
        posts_by_title_and_position(:asc)
        |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p9, p10, p11, p12])
      assert page.metadata.before == encode_cursor([p9.title, p9.position])

      page = posts_by_title_and_position(:asc) |> paginate(opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p1, p7, p8])
      assert page.metadata.after == encode_cursor([p8.title, p8.position])

      assert page.metadata.before == nil
    end
  end

  describe "builds cursor from related user" do
    test "from alias", %{
      posts: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, p10, _p11, _p12}
    } do
      page =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user), as: :user)
        |> preload([p, u], user: u)
        |> order_by([p, u], desc: u.name)
        |> order_by({:desc, :published_at})
        |> paginate(@opts)

      assert page.metadata.after ==
               encode_cursor([p10.user.name, p10.published_at])
    end

    test "from assoc", %{
      posts: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, p10, _p11, _p12}
    } do
      page =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user))
        |> preload([p, u], user: u)
        |> order_by([p, u], desc: u.name)
        |> order_by({:desc, :published_at})
        |> paginate(@opts)

      assert page.metadata.after ==
               encode_cursor([p10.user.name, p10.published_at])
    end

    test "from manual join", %{
      posts: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, p10, _p11, _p12}
    } do
      page =
        Quarto.Post
        |> join(:left, [p], u in Quarto.User, on: p.user_id == u.id)
        |> preload([p, u], user: u)
        |> order_by([p, u], desc: u.name)
        |> order_by({:desc, :published_at})
        |> paginate(@opts)

      assert page.metadata.after ==
               encode_cursor([p10.user.name, p10.published_at])
    end

    test "from 2nd assoc", %{
      profiles: {pr1, _, _},
      posts: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, p10, _p11, _p12}
    } do
      page =
        Quarto.Post
        |> join(:left, [p], u in assoc(p, :user))
        |> join(:left, [p, u], pr in assoc(u, :profile))
        |> preload([p, u, pr], user: {u, profile: pr})
        |> order_by([p, u, pr], desc: pr.title)
        |> order_by({:desc, :published_at})
        |> paginate(@opts)

      assert page.metadata.after ==
               encode_cursor([pr1.title, p10.published_at])
    end
  end

  test "sorts descending with before and after cursor", %{
    posts: {_p1, p2, p3, p4, p5, p6, p7, p8, p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: _metadata} =
      Post
      |> order_by(desc: :position)
      |> Quarto.paginate(
        [
          after: encode_cursor([p9.position]),
          before: encode_cursor([p2.position]),
          limit: 8
        ],
        TestRepo
      )

    assert_receive({:query, query})

    assert "#Ecto.Query<from p0 in Quarto.Post, where: p0.position > ^2 and ^true and ^true, where: p0.position < ^9 and ^true and ^true, order_by: [desc: p0.position], limit: ^9>" ==
             inspect(query)

    assert to_ids(entries) == to_ids([p8, p7, p6, p5, p4, p3])
  end

  test "sorts ascending with before and after cursor", %{
    posts: {_p1, p2, p3, p4, p5, p6, p7, p8, p9, _p10, _p11, _p12}
  } do
    %Page{entries: entries, metadata: _metadata} =
      Post
      |> order_by(asc: :position)
      |> Quarto.paginate(
        [
          before: encode_cursor([p9.position]),
          after: encode_cursor([p2.position]),
          limit: 8
        ],
        TestRepo
      )

    assert_receive({:query, query})

    assert "#Ecto.Query<from p0 in Quarto.Post, where: p0.position < ^9 and ^true and ^true, where: p0.position > ^2 and ^true and ^true, order_by: [asc: p0.position], limit: ^9>" ==
             inspect(query)

    assert to_ids(entries) == to_ids([p3, p4, p5, p6, p7, p8])
  end

  test "paginates without macro", %{
    posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    page = posts_by_published_at(:desc) |> Quarto.paginate(@opts, Quarto.Repo)
    assert to_ids(page.entries) == to_ids([p1, p2, p3, p4])
    assert page.metadata.after == encode_cursor([p4.published_at])

    page =
      posts_by_published_at(:desc)
      |> Quarto.paginate(@opts ++ [after: page.metadata.after], Quarto.Repo)

    assert to_ids(page.entries) == to_ids([p5, p6, p7, p8])
    assert page.metadata.after == encode_cursor([p8.published_at])

    page =
      posts_by_published_at(:desc)
      |> Quarto.paginate(@opts ++ [after: page.metadata.after], Quarto.Repo)

    assert to_ids(page.entries) == to_ids([p9, p10, p11, p12])
    assert page.metadata.after == nil
  end

  test "raises error when a fragment is passed in order_by" do
    assert_raise(ArgumentError, ~r/Fragments not supported currently, got: #Ecto.Query/, fn ->
      Quarto.Post
      |> order_by({:desc, :published_at})
      |> order_by([p], desc: fragment("? % ?", p.id, 2))
      |> paginate(limit: 10)
    end)
  end

  test "malicous payloads are not executed" do
    exploit = fn _, _ ->
      send(self(), :rce)
      {:cont, []}
    end

    payload =
      exploit
      |> :erlang.term_to_binary()
      |> Base.url_encode64()

    assert_raise(ArgumentError, ~r/^cannot deserialize.+/, fn ->
      Post
      |> order_by(asc: :position)
      |> Quarto.paginate(
        [
          before: payload,
          after: payload,
          limit: 8
        ],
        TestRepo
      )
    end)

    refute_receive :rce, 1000, "Remote Code Execution Detected"
  end

  test "raises error when a dynamic is passed in order_by" do
    assert_raise(
      ArgumentError,
      ~r/Unsupported clause passed into order by expr #Ecto.Query/,
      fn ->
        order_by = [desc: dynamic([p], coalesce(p.id, 2))]

        Quarto.Post
        |> order_by(^order_by)
        |> paginate(limit: 10)
      end
    )
  end

  test "raises error when a non-queryable is passed in" do
    assert_raise(ArgumentError, "Expecting an `%Ecto.Query{}` struct, got: []", fn ->
      [] |> paginate(limit: 10)
    end)
  end

  describe "with include_entries" do
    test "when set to false" do
      %Page{metadata: metadata, entries: entries} =
        posts_by_published_at(:desc)
        |> paginate(
          limit: 5,
          total_count_limit: :infinity,
          include_total_count: true,
          include_entries: false
        )

      assert entries == []

      assert metadata == %Metadata{
               before: nil,
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end
  end

  describe "with include_total_count" do
    test "when set to :infinity", %{
      posts: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        posts_by_published_at(:desc)
        |> paginate(
          limit: 5,
          total_count_limit: :infinity,
          include_total_count: true
        )

      assert metadata == %Metadata{
               after: encode_cursor(p5.published_at),
               before: nil,
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap not exceeded", %{
      posts: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        posts_by_published_at(:desc)
        |> paginate(
          limit: 5,
          include_total_count: true
        )

      assert metadata == %Metadata{
               after: encode_cursor(p5.published_at),
               before: nil,
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap exceeded", %{
      posts: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        posts_by_published_at(:desc)
        |> paginate(
          limit: 5,
          include_total_count: true,
          total_count_limit: 10
        )

      assert metadata == %Metadata{
               after: encode_cursor(p5.published_at),
               before: nil,
               limit: 5,
               total_count: 10,
               total_count_cap_exceeded: true
             }
    end

    test "when custom total_count_primary_key_field", %{
      posts: {_p1, p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{metadata: metadata} =
        posts_by_published_at(:desc)
        |> paginate(
          limit: 2,
          include_total_count: true,
          total_count_primary_key_field: :published_at
        )

      assert metadata == %Metadata{
               after: encode_cursor(p2.published_at),
               before: nil,
               limit: 2,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end
  end

  describe "queryable" do
    test "does not add coalesce in ORDER BY clause when default coalesce function returns nil" do
      opts = [limit: 5]

      Quarto.Post |> order_by({:desc, :position}) |> Quarto.paginate(opts, TestRepo)
      assert_receive({:query, queryable})

      assert "#Ecto.Query<from p0 in Quarto.Post, order_by: [desc: p0.position], limit: ^6>" ==
               inspect(queryable)
    end

    test "does add coalesce in ORDER BY clause when default coalesce function returns non-nil" do
      coalesce = fn field, _position, _value ->
        case field do
          :position -> 100
        end
      end

      opts = [limit: 5, coalesce: coalesce]

      Quarto.Post |> order_by({:desc, :position}) |> Quarto.paginate(opts, TestRepo)
      assert_receive({:query, queryable})

      assert "#Ecto.Query<from p0 in Quarto.Post, order_by: [desc: coalesce(p0.position, ^100)], limit: ^6>" ==
               inspect(queryable)
    end

    test "does not add coalesce with 'after' in WHERE and ORDER BY clause when default coalesce function returns nil" do
      opts = [limit: 5, after: [3]]

      Quarto.Post |> order_by({:desc, :position}) |> Quarto.paginate(opts, TestRepo)
      assert_receive({:query, queryable})

      assert "#Ecto.Query<from p0 in Quarto.Post, where: p0.position < ^3 and ^true and ^true, order_by: [desc: p0.position], limit: ^6>" ==
               inspect(queryable)
    end

    test "add coalesces in WHERE < clause when custom coalesce function returns nil" do
      coalesce = fn field, _position, _value ->
        case field do
          :position -> 100
        end
      end

      opts = [limit: 5, after: [3], coalesce: coalesce]

      Quarto.Post |> order_by({:desc, :position}) |> Quarto.paginate(opts, TestRepo)
      assert_receive({:query, queryable})

      assert "#Ecto.Query<from p0 in Quarto.Post, where: coalesce(p0.position, ^100) < ^3 and ^true and ^true, order_by: [desc: coalesce(p0.position, ^100)], limit: ^6>" ==
               inspect(queryable)
    end

    test "add coalesces in WHERE > clause when custom coalesce function returns nil" do
      coalesce = fn field, _position, _value ->
        case field do
          :position -> 100
        end
      end

      opts = [limit: 5, before: [3], coalesce: coalesce]

      Quarto.Post |> order_by({:desc, :position}) |> Quarto.paginate(opts, TestRepo)
      assert_receive({:query, queryable})

      assert "#Ecto.Query<from p0 in Quarto.Post, where: coalesce(p0.position, ^100) > ^3 and ^true and ^true, order_by: [asc: coalesce(p0.position, ^100)], limit: ^6>" ==
               inspect(queryable)
    end

    test "add coalesces in WHERE == clause when custom coalesce function returns nil for multiple sort_fields" do
      coalesce = fn field, _position, _value ->
        case field do
          :position -> 100
          :id -> 10
        end
      end

      opts = [limit: 5, after: [3, 10], coalesce: coalesce]

      Quarto.Post
      |> order_by({:desc, :position})
      |> order_by({:asc, :id})
      |> Quarto.paginate(opts, TestRepo)

      assert_receive({:query, queryable})

      assert """
             #Ecto.Query<from p0 in Quarto.Post, where: (coalesce(p0.position, ^100) == ^3 and (coalesce(p0.id, ^10) > ^10 and ^true)) or
               (coalesce(p0.position, ^100) < ^3 and ^true and ^true), order_by: [desc: coalesce(p0.position, ^100), asc: coalesce(p0.id, ^10)], limit: ^6>
             """ == inspect(queryable) <> "\n"
    end
  end

  defp cursor_values_from_fields(fields, post) do
    Enum.map(fields, fn
      {rel, field} ->
        Map.fetch!(post, rel) |> Map.fetch!(field)

      field ->
        Map.fetch!(post, field)
    end)
  end

  defp generate_run(opts \\ [min_length: 0]) do
    gen all(
          direction <- one_of_direction(),
          fields <- post_order_field_list(),
          title <- map(string(:ascii), fn s -> "title " <> s end),
          post_list <- post_list(title, opts),
          limit <- positive_integer()
        ) do
      %Run{
        direction: direction,
        fields: fields,
        posts: post_list,
        limit: limit,
        title: title
      }
    end
  end

  defp to_ids(entries), do: Enum.map(entries, & &1.id)

  defp encode_cursor(value) do
    {:ok, cursor} = Cursor.Base64.encode(value)
    cursor
  end

  defp posts_by_title_and_position(order) do
    Quarto.Post |> order_by({^order, :title}) |> order_by({^order, :position})
  end

  defp posts_by_published_at(order) do
    Quarto.Post |> order_by({^order, :published_at})
  end

  defp paginate(queryable, opts) do
    Quarto.Repo.paginate(queryable, opts)
  end

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-(days * 86_400))
    |> DateTime.truncate(:second)
  end

  def one_of_direction() do
    one_of([constant(:asc), constant(:desc)])
  end

  def post_order_field_list() do
    deterministic =
      one_of([
        list_of(
          resize(one_of([constant(:id), constant(:position), constant(:published_at)]), 1000),
          min_length: 1,
          max_length: 3
        )
      ])

    optional = list_of(one_of([:user_id, {:user, :name}]), max_length: 2)

    bind(deterministic, fn deterministic ->
      bind(optional, fn nondeterministic ->
        # At least one deterministic field to sort by to get deterministic results
        constant(deterministic ++ nondeterministic)
      end)
    end)
  end

  def user_list(length) do
    uniq_list_of(
      map(string(:ascii), fn name ->
        insert(:user, name: name)
      end),
      length: length,
      uniq_fun: fn u -> u.name end
    )
  end

  def post_list(run, opts \\ [min_length: 0]) do
    gen all(
          positions <- uniq_list_of(resize(integer(), 1000), min_length: opts[:min_length]),
          days <-
            uniq_list_of(resize(positive_integer(), 1000), length: Kernel.length(positions)),
          users <- user_list(Kernel.length(positions))
        ) do
      positions
      |> Enum.zip(days)
      |> Enum.zip(users)
      |> Enum.map(fn {{position, day}, user} ->
        insert(:post,
          user: user,
          title: run,
          position: position,
          published_at: datetime_from_now(days: -1 * day)
        )
      end)
    end
  end

  defp cleanup!(run) do
    Quarto.Post |> where(title: ^run) |> Repo.delete_all()
  end

  defp create_posts(_context) do
    user3 = insert(:user, name: "Alice")
    user2 = insert(:user, name: "Bob")
    user1 = insert(:user, name: "Charlie", photo: "photo.jpg")

    profile1 = insert(:profile, title: "Profile Charlie", user: user1)
    profile2 = insert(:profile, title: "Profile Bob", user: user2)
    profile3 = insert(:profile, title: "Profile Alice", user: user3)

    p1 = insert(:post, user: user1, title: "A", position: 1, published_at: days_ago(1))
    p2 = insert(:post, user: user2, title: nil, position: 2, published_at: days_ago(2))
    p3 = insert(:post, user: user3, title: nil, position: 3, published_at: days_ago(3))

    p4 = insert(:post, user: user1, title: nil, position: 4, published_at: days_ago(4))
    p5 = insert(:post, user: user2, title: nil, position: 5, published_at: days_ago(5))
    p6 = insert(:post, user: user3, title: nil, position: 6, published_at: days_ago(6))

    p7 = insert(:post, user: user1, title: "B", position: 7, published_at: days_ago(7))
    p8 = insert(:post, user: user2, title: "C", position: 8, published_at: days_ago(8))
    p9 = insert(:post, user: user3, title: "D", position: 9, published_at: days_ago(9))

    p10 = insert(:post, user: user1, title: "E", position: 10, published_at: days_ago(10))
    p11 = insert(:post, user: user2, title: "F", position: 11, published_at: days_ago(11))
    p12 = insert(:post, user: user3, title: "G", position: 12, published_at: days_ago(12))

    {:ok,
     profiles: {profile1, profile2, profile3},
     posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}}
  end

  defp datetime_from_now(days: days) do
    DateTime.utc_now() |> DateTime.add(days * 86_400) |> DateTime.truncate(:second)
  end

  defp split_of_cursor_post(posts) do
    [first | posts] = Enum.reverse(posts)

    {first, Enum.reverse(posts)}
  end

  defp rebuild_list_forward(_query, %{metadata: %{after: nil}} = res, _opts) do
    res
  end

  defp rebuild_list_forward(query, %{metadata: %{after: after_cursor}} = result, opts) do
    new_result = Quarto.Repo.paginate(query, Keyword.merge(opts, after: after_cursor))

    new_result = %{new_result | entries: result.entries ++ new_result.entries}
    rebuild_list_forward(query, new_result, opts)
  end

  defp rebuild_list_backward(_query, %{metadata: %{before: nil}} = res, _opts) do
    res
  end

  defp rebuild_list_backward(query, %{metadata: %{before: before_cursor}} = result, opts) do
    new_result = Quarto.Repo.paginate(query, Keyword.merge(opts, before: before_cursor))

    new_result = %{new_result | entries: new_result.entries ++ result.entries}
    rebuild_list_backward(query, new_result, opts)
  end

  defp sort_by_fields(posts, fields, direction) do
    posts
    |> Enum.sort_by(
      fn post ->
        Enum.map(fields, fn
          {rel, field} ->
            related = Map.fetch!(post, rel)
            Map.fetch!(related, field) |> sortable_value

          field ->
            Map.fetch!(post, field) |> sortable_value
        end)
        |> List.to_tuple()
      end,
      direction
    )
  end

  defp sortable_value(val) when is_integer(val), do: val
  defp sortable_value(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp sortable_value(val), do: val

  defp build_order_by(query, post_fields, direction) do
    Enum.reduce(post_fields, query, fn
      # hardcode user.name joined order by
      {:user, :name}, query ->
        query |> order_by([p, u], {^direction, u.name})

      field, query ->
        query |> order_by({^direction, ^field})
    end)
  end
end
