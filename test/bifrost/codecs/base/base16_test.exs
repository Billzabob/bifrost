defmodule Bifrost.Codecs.Base.Base16Test do
  use ExUnit.Case
  use ExUnitProperties
  import Bifrost
  import Bifrost.Codecs.Base.Base16

  doctest Bifrost.Codecs.Base.Base16

  property "Base16.encode/decode is idempotent" do
    check all(bin <- binary()) do
      assert bin == bin |> decode(codec()) |> elem(1) |> encode(codec()) |> elem(1)
    end
  end

  property "Base16 encoding only contains characters from its alphabet" do
    check all(bin <- binary()) do
      alphabet = "0123456789ABCDEF" |> String.codepoints()
      base16 = bin |> decode(codec()) |> elem(1)

      chars_not_in_alphabet =
        base16
        |> String.codepoints()
        |> Enum.filter(fn char -> !Enum.member?(alphabet, char) end)

      assert chars_not_in_alphabet == []
    end
  end

  # https://datatracker.ietf.org/doc/html/rfc4648#section-10
  test "RFC4648 test vectors" do
    assert {:ok, "", <<>>} = "" |> decode(codec())
    assert {:ok, ""} = "" |> encode(codec())

    assert {:ok, "66", <<>>} = "f" |> decode(codec())
    assert {:ok, "f"} = "66" |> encode(codec())

    assert {:ok, "666F", <<>>} = "fo" |> decode(codec())
    assert {:ok, "fo"} = "666F" |> encode(codec())

    assert {:ok, "666F6F", <<>>} = "foo" |> decode(codec())
    assert {:ok, "foo"} = "666F6F" |> encode(codec())

    assert {:ok, "666F6F62", <<>>} = "foob" |> decode(codec())
    assert {:ok, "foob"} = "666F6F62" |> encode(codec())

    assert {:ok, "666F6F6261", <<>>} = "fooba" |> decode(codec())
    assert {:ok, "fooba"} = "666F6F6261" |> encode(codec())

    assert {:ok, "666F6F626172", <<>>} = "foobar" |> decode(codec())
    assert {:ok, "foobar"} = "666F6F626172" |> encode(codec())
  end
end
