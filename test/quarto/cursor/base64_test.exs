defmodule Quarto.Cursor.Base64Test do
  use ExUnit.Case, async: true

  alias Quarto.Cursor

  defmodule MYTEST1 do
    defstruct id: nil
  end

  defmodule MYTEST2 do
    defstruct id: nil
  end

  defimpl Quarto.Cursor.Encode, for: MYTEST1 do
    def convert(term), do: {:m1, term.id}
  end

  defimpl Quarto.Cursor.Decode, for: Tuple do
    def convert({:m1, id}), do: %MYTEST1{id: id}
  end

  describe "encoding and decoding terms" do
    test "cursor for struct with custom implementation is shorter" do
      cursor1 = Cursor.Base64.encode!([%MYTEST1{id: 1}])

      assert Cursor.Base64.decode!(cursor1) == [%MYTEST1{id: 1}]

      cursor2 = Cursor.Base64.encode!([%MYTEST2{id: 1}])

      assert Cursor.Base64.decode!(cursor2) == [%MYTEST2{id: 1}]
      assert bit_size(cursor1) < bit_size(cursor2)
    end

    test "it wraps terms into lists" do
      cursor = Cursor.Base64.encode!(1)

      assert Cursor.Base64.decode!(cursor) == [1]
    end

    test "it doesn't wrap a list in a list" do
      cursor = Cursor.Base64.encode!([1])

      assert Cursor.Base64.decode!(cursor) == [1]
      refute Cursor.Base64.decode!(cursor) == [[1]]
    end
  end

  describe "Cursor.Base64.decode/1" do
    test "it safely decodes user input" do
      assert_raise ArgumentError, fn ->
        # this binary represents the atom :fubar_0a1b2c3d4e
        <<131, 100, 0, 16, "fubar_0a1b2c3d4e">>
        |> Base.url_encode64()
        |> Cursor.Base64.decode!()
      end
    end

    test "it returns error for bogus cursor" do
      assert {:error, :base64_decode_error} == Cursor.Base64.decode("❌")
    end

    test "it raises error for bogus cursor" do
      assert_raise ArgumentError, fn -> Cursor.Base64.decode!("❌") end
    end
  end
end
