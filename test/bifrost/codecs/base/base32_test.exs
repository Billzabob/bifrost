defmodule Bifrost.Codecs.Base.Base32Test do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Bifrost
  import Bifrost.Codecs.Base.Base32

  doctest Bifrost.Codecs.Base.Base32

  property "Base32.encode/decode is idempotent" do
    check all(bin <- binary()) do
      assert bin == bin |> decode(codec()) |> elem(1) |> encode(codec()) |> elem(1)
    end
  end

  property "Base32 encoding only contains characters from its alphabet" do
    check all(bin <- binary()) do
      alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=" |> String.codepoints()
      base32 = bin |> decode(codec()) |> elem(1)

      chars_not_in_alphabet =
        base32
        |> String.codepoints()
        |> Enum.filter(fn char -> !Enum.member?(alphabet, char) end)

      assert chars_not_in_alphabet == []
    end
  end

  test "decodes to 1 byte" do
    assert {:ok, "JU======", <<>>} = <<77>> |> decode(codec())
  end

  test "decodes to 2 bytes" do
    assert {:ok, "JVQQ====", <<>>} = <<77, 97>> |> decode(codec())
  end

  test "decodes to 3 bytes" do
    assert {:ok, "JVQW4===", <<>>} = <<77, 97, 110>> |> decode(codec())
  end

  test "decodes to 4 bytes" do
    assert {:ok, "JVQW42Y=", <<>>} = <<77, 97, 110, 107>> |> decode(codec())
  end

  test "decodes to 5 bytes" do
    assert {:ok, "JVQW423J", <<>>} = <<77, 97, 110, 107, 105>> |> decode(codec())
  end

  test "encodes 1 byte" do
    assert {:ok, <<77>>} = "JU======" |> encode(codec())
  end

  test "encodes 2 bytes" do
    assert {:ok, <<77, 97>>} = "JVQQ====" |> encode(codec())
  end

  test "encodes 3 bytes" do
    assert {:ok, <<77, 97, 110>>} = "JVQW4===" |> encode(codec())
  end

  test "encodes 4 bytes" do
    assert {:ok, <<77, 97, 110, 107>>} = "JVQW42Y=" |> encode(codec())
  end

  test "encodes 5 bytes" do
    assert {:ok, <<77, 97, 110, 107, 105>>} = "JVQW423J" |> encode(codec())
  end

  # https://datatracker.ietf.org/doc/html/rfc4648#section-10
  test "RFC4648 test vectors" do
    assert {:ok, "", <<>>} = "" |> decode(codec())
    assert {:ok, ""} = "" |> encode(codec())

    assert {:ok, "MY======", <<>>} = "f" |> decode(codec())
    assert {:ok, "f"} = "MY======" |> encode(codec())

    assert {:ok, "MZXQ====", <<>>} = "fo" |> decode(codec())
    assert {:ok, "fo"} = "MZXQ====" |> encode(codec())

    assert {:ok, "MZXW6===", <<>>} = "foo" |> decode(codec())
    assert {:ok, "foo"} = "MZXW6===" |> encode(codec())

    assert {:ok, "MZXW6YQ=", <<>>} = "foob" |> decode(codec())
    assert {:ok, "foob"} = "MZXW6YQ=" |> encode(codec())

    assert {:ok, "MZXW6YTB", <<>>} = "fooba" |> decode(codec())
    assert {:ok, "fooba"} = "MZXW6YTB" |> encode(codec())

    assert {:ok, "MZXW6YTBOI======", <<>>} = "foobar" |> decode(codec())
    assert {:ok, "foobar"} = "MZXW6YTBOI======" |> encode(codec())
  end
end
