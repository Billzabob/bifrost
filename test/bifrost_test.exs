defmodule BinCodexTest do
  use ExUnit.Case, async: true
  import Bifrost
  import ExUnitProperties
  alias StreamData, as: Prop

  defmodule Foo do
    defstruct a: nil, b: nil
  end

  doctest Bifrost, import: true

  describe "combine/2" do
    test "creates a codec of a tuple of the supplied values" do
      codec = combine(byte(), byte())
      assert {:ok, <<1, 2>>} == {1, 2} |> encode(codec)
      assert {:ok, {1, 2}, <<>>} == <<1, 2>> |> decode(codec)

      codec = combine(byte(), list(byte()))
      assert {:ok, <<1, 1, 2, 3>>} == {1, [1, 2, 3]} |> encode(codec)
      assert {:ok, {1, [1, 2, 3]}, <<>>} == <<1, 1, 2, 3>> |> decode(codec)

      codec = combine(byte(), combine(byte(), byte()))
      assert {:ok, <<1, 2, 3>>} == {1, {2, 3}} |> encode(codec)
      assert {:ok, {1, {2, 3}}, <<>>} == <<1, 2, 3>> |> decode(codec)
    end

    property "is idempotent" do
      check all(tuple <- Prop.tuple({Prop.byte(), Prop.byte()})) do
        codec = combine(byte(), byte())
        assert is_idempotent?(codec, tuple)
      end
    end
  end

  describe "value/1" do
    test "creates a codec that always decodes to that value" do
      codec = value(1)
      assert {:ok, <<>>} == 1 |> encode(codec)
      assert {:ok, 1, <<>>} == <<>> |> decode(codec)

      codec = value("test")
      assert {:ok, <<>>} == "test" |> encode(codec)
      assert {:ok, "test", <<>>} == <<>> |> decode(codec)

      codec = value(%{a: 1, b: 2})
      assert {:ok, <<>>} == %{a: 1, b: 2} |> encode(codec)
      assert {:ok, %{a: 1, b: 2}, <<>>} == <<>> |> decode(codec)
    end

    property "is idempotent" do
      check all(term <- Prop.term()) do
        codec = value(term)
        assert is_idempotent?(codec, term)
      end
    end
  end

  describe "empty/0" do
    test "creates a codec that always decodes to an empty list" do
      codec = empty()
      assert {:ok, <<>>} == [] |> encode(codec)
      assert {:ok, [], <<>>} == <<>> |> decode(codec)
    end

    property "is idempotent" do
      assert is_idempotent?(empty(), [])
    end
  end

  describe "nothing/0" do
    test "creates a codec that always decodes to nil" do
      codec = nothing()
      assert {:ok, <<>>} == nil |> encode(codec)
      assert {:ok, nil, <<>>} == <<>> |> decode(codec)
    end

    property "is idempotent" do
      assert is_idempotent?(nothing(), nil)
    end
  end

  defp is_idempotent?(codec, sample) do
    encoded = sample |> encode(codec) |> elem(1)
    {:ok, decoded, remaining_bits} = encoded |> decode(codec)
    re_encoded = decoded |> encode(codec) |> elem(1)
    encoded == re_encoded && remaining_bits == <<>>
  end
end
