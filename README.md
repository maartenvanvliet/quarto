# Quarto

## [![Hex pm](http://img.shields.io/hexpm/v/quarto.svg?style=flat)](https://hex.pm/packages/quarto) [![Hex Docs](https://img.shields.io/badge/hex-docs-9768d1.svg)](https://hexdocs.pm/quarto) [![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)![.github/workflows/elixir.yml](https://github.com/maartenvanvliet/quarto/workflows/.github/workflows/elixir.yml/badge.svg)

---

> Quarto (abbreviated Qto, 4to or 4º) is a book or pamphlet produced from full "blanksheets", each of which is printed with eight pages of text, four to a side, then folded twice to produce four leaves. The leaves are then trimmed along the folds to produce eight book pages. Each printed page presents as one-fourth size of the full blanksheet. (https://en.wikipedia.org/wiki/Quarto)

Quarto is a is a _keyset-based_ pagination library for `Ecto` but confusingly the it is also referred to as cursor-based pagination. (Though cursor based pagination also means something else).

In this case it means that the pagination relies on an opaque cursor to figure out where to start with the next batch of records. See https://use-the-index-luke.com/no-offset

This library is ported from https://github.com/duffelhq/paginator/ but has some important backwards incompatible differences that warrant a new library.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `quarto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:quarto, "~> 1.0.0"}
  ]
end
```

## Usage

You can add `Quarto` to your `Ecto.Repo`.

```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo, otp_app: :my_app
    use Quarto, limit: 10
  end
```

It adds the `paginate/3` function to your repository which you can use to paginate through a resultset. See `Quarto.paginate/4` on the options that can be passed to `use Quarto`.

To paginate you can query an Ecto schema like you normally would. It is important that the columns you order by are deterministically ordered. If there are null values in the columns or if two rows have the same values in the columns you order by the results may be wrong. To fix this you can always add an extra unique column to order by.

The columns you order by will also be used to construct the opaque cursor that can be used to retrieve the next set of results.

```elixir
# First set of results
%{entries: entries, metadata: metadata} = Post |> order_by(desc: :user_id) |> order_by({^order,:published_at}) |> MyApp.Repo.paginate

after_cursor = metadata.after
# Next set of results
%{entries: entries, metadata: metadata} = Post |> order_by(desc: :user_id) |> order_by({^order,:published_at}) |> MyApp.Repo.paginate(after: after_cursor)

# Get the before cursor
before_cursor = metadata.before

# Previous set of results
%{entries: entries, metadata: metadata} = Post |> order_by(desc: :user_id) |> order_by({^order,:published_at}) |> MyApp.Repo.paginate(before: before_cursor)


%{entries: entries, metadata: metadata} = Post |> order_by(desc: :user_id) |> order_by({^order,:published_at}) |> MyApp.Repo.paginate(include_total_count: true)

# Total count of rows satisfying the query
metadata.total_count
```

## Advanced usage

Some more advanced use cases are shown below.

#### Without a macro

If you cannot use the macro in the repo you can still use Quarto.

```elixir
Quarto.Post
|> order_by(desc: :published_at)
|> Quarto.paginate([], MyApp.Repo)
```

Simply call `Quarto.paginate(queryable, opts, MyApp.Repo, repo_opts)` with your repo as the third argument.

#### Joining on related tables

In addition to ordering by a field on the current table it's also possible to order on the field of a related table.

E.g. in this example the ordering of the posts is by the name of the related user and the published_at date of the post.

```elixir
Quarto.Post
|> join(:left, [p], u in assoc(p, :user), as: :user)
|> preload([p, u], user: u)
|> order_by([p, u], desc: u.name)
|> order_by(desc: :published_at)
|> Repo.paginate
```

What's important is that the `preload` function loads the user. This is necessary
for when the cursor for the next result set is created as it needs the name of the user and the published_at of the post to create the new cursor.

#### Passing in the cursor

Although in normal usage the encoded cursor can be passed in. It's possible to
use a normal erlang term as well.

```elixir
Quarto.Post
|> join(:left, [p], u in assoc(p, :user), as: :user)
|> preload([p, u], user: u)
|> order_by([p, u], desc: u.name)
|> order_by(desc: :id)
|> Repo.paginate(after: ["Alice", 10])
```

#### Implementing a custom cursor

A default cursor implementation is provided but you can provide a custom implementation. E.g. to sign the cursors. The codec needs to implement the
`Quarto.Cursor` behaviour. See `Quarto.Cursor.Base64` for an example

#### Encoding/decoding cursor values

Normally a cursor is composed out of a list of values of one or more fields in the database. How each field is encoded/decoded depends on its type and can be
controlled with the `Quarto.Cursor.Decode` and `Quarto.Cursor.Encode` protocols.
See those modules for examples how you can override this

#### Fragments

Ecto fragments provide ways to use custom SQL expressions in your ecto queries.
Quarto does not support them in the `order_by` clause.

#### NULL values

NULL values in columns can be problematic for Quarto. Using coalescing it's possible to order by NULL values by coalescing them into a known value.
E.g. when there are NULL values in a datetime column, the NULL values can be coalesced into the max or min datetime your database supports, depending on where you want them in your resultset.

In the following example the `title` field has NULL values and therefore hard to order by. If we order alphabetically and asc and decide to place the rows with NULL values at the end we need to coalesce the NULL values to e.g. `ZZZZZZZ`. It's important that it's a value higher than any other in that column.

```elixir
coalesce = fn field, position, value ->
  case field do
    :title -> "ZZZZZZZ"
    _ -> value
  end
end

Quarto.Post |> order_by({:asc, :title}) |> order_by({:asc, :position}) |> MyApp.Repo.paginate(limit: 4, coalesce: coalesce)

```

The field with the name

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/quarto](https://hexdocs.pm/quarto).
