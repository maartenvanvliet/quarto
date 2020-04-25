defmodule QuartoTest do
  use Quarto.DataCase, async: true

  alias Quarto.Cursor
  alias Quarto.Page
  alias Quarto.Page.Metadata

  setup :create_posts

  @opts [limit: 4]

  describe "paginate descending, 1 cursor field" do
    test "paginates forward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page = posts_by_published_at(:desc) |> paginate(@opts)
      assert to_ids(page.entries) == to_ids([p1, p2, p3, p4])
      assert page.metadata.after == encode_cursor([p4.published_at])

      page = posts_by_published_at(:desc) |> paginate(@opts ++ [after: page.metadata.after])
      assert to_ids(page.entries) == to_ids([p5, p6, p7, p8])
      assert page.metadata.after == encode_cursor([p8.published_at])

      page = posts_by_published_at(:desc) |> paginate(@opts ++ [after: page.metadata.after])
      assert to_ids(page.entries) == to_ids([p9, p10, p11, p12])
      assert page.metadata.after == nil
    end

    test "paginates backward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page =
        posts_by_published_at(:desc)
        |> paginate(@opts ++ [before: encode_cursor([p12.published_at])])

      assert to_ids(page.entries) == to_ids([p8, p9, p10, p11])
      assert page.metadata.before == encode_cursor([p8.published_at])

      page = posts_by_published_at(:desc) |> paginate(@opts ++ [before: page.metadata.before])
      assert to_ids(page.entries) == to_ids([p4, p5, p6, p7])
      assert page.metadata.before == encode_cursor([p4.published_at])

      page = posts_by_published_at(:desc) |> paginate(@opts ++ [before: page.metadata.before])
      assert to_ids(page.entries) == to_ids([p1, p2, p3])
      assert page.metadata.after == encode_cursor([p3.published_at])

      assert page.metadata.before == nil
    end

    test "paginates backward with erlang term cursor", %{
      posts: {_p1, _p2, _p3, _p4, p5, p6, p7, p8, p9, _p10, _p11, _p12}
    } do
      page = posts_by_published_at(:desc) |> paginate(@opts ++ [{:before, [p9.published_at]}])
      assert to_ids(page.entries) == to_ids([p5, p6, p7, p8])
      assert page.metadata.before == encode_cursor([p5.published_at])
    end

    test "paginates forward with erlang term cursor", %{
      posts: {_p1, _p2, _p3, p4, p5, p6, p7, p8, _p9, _p10, _p11, _p12}
    } do
      page = posts_by_published_at(:desc) |> paginate(@opts ++ [{:after, [p4.published_at]}])
      assert to_ids(page.entries) == to_ids([p5, p6, p7, p8])
      assert page.metadata.after == encode_cursor([p8.published_at])
    end
  end

  describe "paginate ascending, 1 cursor field" do
    test "paginates forward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page = posts_by_published_at(:asc) |> paginate(@opts)
      assert to_ids(page.entries) == to_ids([p12, p11, p10, p9])
      assert page.metadata.after == encode_cursor([p9.published_at])

      page = posts_by_published_at(:asc) |> paginate(@opts ++ [after: page.metadata.after])
      assert to_ids(page.entries) == to_ids([p8, p7, p6, p5])
      assert page.metadata.after == encode_cursor([p5.published_at])

      page = posts_by_published_at(:asc) |> paginate(@opts ++ [after: page.metadata.after])
      assert to_ids(page.entries) == to_ids([p4, p3, p2, p1])
      assert page.metadata.after == nil
    end

    test "paginates backward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page =
        posts_by_published_at(:asc)
        |> paginate(@opts ++ [before: encode_cursor([p1.published_at])])

      assert to_ids(page.entries) == to_ids([p5, p4, p3, p2])
      assert page.metadata.before == encode_cursor([p5.published_at])

      page = posts_by_published_at(:asc) |> paginate(@opts ++ [before: page.metadata.before])
      assert to_ids(page.entries) == to_ids([p9, p8, p7, p6])
      assert page.metadata.before == encode_cursor([p9.published_at])

      page = posts_by_published_at(:asc) |> paginate(@opts ++ [before: page.metadata.before])
      assert to_ids(page.entries) == to_ids([p12, p11, p10])
      assert page.metadata.after == encode_cursor([p10.published_at])

      assert page.metadata.before == nil
    end
  end

  describe "paginate descending, 2 cursor fields" do
    test "paginates forward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page = posts_by_user_and_published_at(:desc) |> paginate(@opts)
      assert to_ids(page.entries) == to_ids([p1, p4, p7, p10])
      assert page.metadata.after == encode_cursor([p10.user_id, p10.published_at])

      page =
        posts_by_user_and_published_at(:desc) |> paginate(@opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p2, p5, p8, p11])
      assert page.metadata.after == encode_cursor([p11.user_id, p11.published_at])

      page =
        posts_by_user_and_published_at(:desc) |> paginate(@opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p3, p6, p9, p12])
      assert page.metadata.after == nil
    end

    test "paginates backward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      posts_by_user_and_published_at(:desc) |> Quarto.Repo.all()

      page =
        posts_by_user_and_published_at(:desc)
        |> paginate(@opts ++ [before: encode_cursor([p12.user_id, p12.published_at])])

      assert to_ids(page.entries) == to_ids([p11, p3, p6, p9])
      assert page.metadata.before == encode_cursor([p11.user_id, p11.published_at])

      page =
        posts_by_user_and_published_at(:desc)
        |> paginate(@opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p10, p2, p5, p8])
      assert page.metadata.before == encode_cursor([p10.user_id, p10.published_at])

      page =
        posts_by_user_and_published_at(:desc) |> paginate(@opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p1, p4, p7])
      assert page.metadata.after == encode_cursor([p7.user_id, p7.published_at])

      assert page.metadata.before == nil
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
            coalesce: fn field, _position, value ->
              case field do
                :title -> "0"
                _ -> value
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

  describe "paginate posts by user name descending, 2 cursor fields" do
    test "paginates forward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page = posts_by_user_name_and_published_at(:desc) |> paginate(@opts)
      assert to_ids(page.entries) == to_ids([p1, p4, p7, p10])

      assert page.metadata.after ==
               encode_cursor([p10.user.name, p10.published_at])

      page =
        posts_by_user_name_and_published_at(:desc)
        |> paginate(@opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p2, p5, p8, p11])
      assert page.metadata.after == encode_cursor([p11.user.name, p11.published_at])

      page =
        posts_by_user_name_and_published_at(:desc)
        |> paginate(@opts ++ [after: page.metadata.after])

      assert to_ids(page.entries) == to_ids([p3, p6, p9, p12])
      assert page.metadata.after == nil
    end

    test "paginates backward", %{
      posts: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      page =
        posts_by_user_name_and_published_at(:desc)
        |> paginate(@opts ++ [before: encode_cursor([p12.user.name, p12.published_at])])

      assert to_ids(page.entries) == to_ids([p11, p3, p6, p9])
      assert page.metadata.before == encode_cursor([p11.user.name, p11.published_at])

      page =
        posts_by_user_name_and_published_at(:desc)
        |> paginate(@opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p10, p2, p5, p8])
      assert page.metadata.before == encode_cursor([p10.user.name, p10.published_at])

      page =
        posts_by_user_name_and_published_at(:desc)
        |> paginate(@opts ++ [before: page.metadata.before])

      assert to_ids(page.entries) == to_ids([p1, p4, p7])
      assert page.metadata.after == encode_cursor([p7.user.name, p7.published_at])

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

  test "returns an empty page when there are no results" do
    page =
      unpublished_posts()
      |> paginate(limit: 10)

    assert page.entries == []
    assert page.metadata.after == nil
    assert page.metadata.before == nil
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

  defp to_ids(entries), do: Enum.map(entries, & &1.id)

  defp encode_cursor(value) do
    {:ok, cursor} = Cursor.Base64.encode(value)
    cursor
  end

  defp unpublished_posts do
    Quarto.Post |> where([p], is_nil(p.published_at)) |> order_by({:desc, :published_at})
  end

  defp posts_by_title_and_position(order) do
    Quarto.Post |> order_by({^order, :title}) |> order_by({^order, :position})
  end

  defp posts_by_user_and_published_at(order) do
    Quarto.Post |> order_by({^order, :user_id}) |> order_by({^order, :published_at})
  end

  defp posts_by_user_name_and_published_at(order) do
    Quarto.Post
    |> join(:left, [p], u in assoc(p, :user), as: :user)
    |> preload([p, u], user: u)
    |> order_by([p, u], desc: u.name)
    |> order_by({^order, :published_at})
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
end
