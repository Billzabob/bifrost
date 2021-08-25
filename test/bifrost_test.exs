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
      codec = combine(uint(8), uint(8))
      assert {:ok, <<1, 2>>} == {1, 2} |> encode(codec)
      assert {:ok, {1, 2}, <<>>} == <<1, 2>> |> decode(codec)

      codec = combine(uint(8), list(uint(8)))
      assert {:ok, <<1, 1, 2, 3>>} == {1, [1, 2, 3]} |> encode(codec)
      assert {:ok, {1, [1, 2, 3]}, <<>>} == <<1, 1, 2, 3>> |> decode(codec)

      codec = combine(uint(8), combine(uint(8), uint(8)))
      assert {:ok, <<1, 2, 3>>} == {1, {2, 3}} |> encode(codec)
      assert {:ok, {1, {2, 3}}, <<>>} == <<1, 2, 3>> |> decode(codec)
    end

    property "is idempotent" do
      check all(
              term1 <- Prop.term(),
              bits1 <- Prop.bitstring(),
              term2 <- Prop.term(),
              bits2 <- Prop.bitstring()
            ) do
        codec = combine(constant(term1, bits1), constant(term2, bits2))
        assert is_idempotent?(codec, {term1, term2})
      end
    end
  end

  describe "constant/2" do
    test "creates a codec that always decodes to and from the same values" do
      codec = constant(1, <<>>)
      assert {:ok, <<>>} == 1 |> encode(codec)
      assert {:ok, 1, <<>>} == <<>> |> decode(codec)

      codec = constant("test", <<1, 2, 3>>)
      assert {:ok, <<1, 2, 3>>} == "test" |> encode(codec)
      assert {:ok, "test", <<>>} == <<1, 2, 3>> |> decode(codec)

      codec = constant({}, <<1, 2, 3>>)
      assert {:ok, <<1, 2, 3>>} == {} |> encode(codec)
      assert {:ok, {}, <<>>} == <<1, 2, 3>> |> decode(codec)
    end

    property "is idempotent" do
      check all(
              term <- Prop.term(),
              bits <- Prop.bitstring()
            ) do
        codec = constant(term, bits)
        assert is_idempotent?(codec, term)
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

  describe "fallback/2" do
    test "creates a codec that falls back to the other codec if the first fails" do
      codec = fallback(uint(4), uint(8))
      assert {:ok, <<1::4>>} == 1 |> encode(codec)
      assert {:ok, 1, <<>>} == <<1::4>> |> decode(codec)

      codec = fallback(uint(8), uint(4))
      assert {:ok, <<2>>} == 2 |> encode(codec)
      assert {:ok, 2, <<>>} == <<2>> |> decode(codec)

      codec = fallback(fail("uh oh"), list(uint(8)))
      assert {:ok, <<1, 2, 3>>} == [1, 2, 3] |> encode(codec)
      assert {:ok, [1, 2, 3], <<>>} == <<1, 2, 3>> |> decode(codec)
    end

    property "is idempotent" do
      check all(
              term1 <- Prop.term(),
              bits1 <- Prop.bitstring(),
              term2 <- Prop.term(),
              bits2 <- Prop.bitstring(),
              sample <- Prop.one_of([Prop.constant(term1), Prop.constant(term2)])
            ) do
        codec = fallback(constant(term1, bits1), constant(term2, bits2))
        assert is_idempotent?(codec, sample)
      end
    end
  end

  describe "fail/1" do
    property "always fails" do
      check all(
              string <- Prop.string(:printable),
              term <- Prop.term(),
              bits <- Prop.bitstring()
            ) do
        codec = fail(string)
        assert {:error, ^string, ^term} = term |> encode(codec)
        assert {:error, ^string, ^bits} = bits |> decode(codec)
      end
    end
  end

  defp is_idempotent?(codec, a) do
    bits = a |> encode(codec) |> elem(1)

    assert {:ok, decoded1, _} = a |> encode_then_decode(codec)
    assert {:ok, decoded2, <<>>} = decoded1 |> encode_then_decode(codec)

    assert {:ok, encoded1} = bits |> decode_then_encode(codec)
    assert {:ok, encoded2} = encoded1 |> decode_then_encode(codec)

    assert decoded1 == decoded2
    assert encoded1 == encoded2
  end

  defp encode_then_decode(a, codec) do
    a |> encode(codec) |> elem(1) |> decode(codec)
  end

  defp decode_then_encode(bits, codec) do
    bits |> decode(codec) |> elem(1) |> encode(codec)
  end
end
