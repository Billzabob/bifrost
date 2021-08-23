defmodule Bifrost.Codecs.Base.Base64Test do
  use ExUnit.Case
  use ExUnitProperties
  import Bifrost
  import Bifrost.Codecs.Base.Base64

  doctest Bifrost.Codecs.Base.Base64

  property "Base64.encode/decode is idempotent" do
    check all(bin <- binary()) do
      assert bin == bin |> decode(codec()) |> elem(1) |> encode(codec()) |> elem(1)
    end
  end

  property "Base64 encoding only contains characters from its alphabet" do
    check all(bin <- binary()) do
      alphabet =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
        |> String.codepoints()

      base64 = bin |> decode(codec()) |> elem(1)

      chars_not_in_alphabet =
        base64
        |> String.codepoints()
        |> Enum.filter(fn char -> !Enum.member?(alphabet, char) end)

      assert chars_not_in_alphabet == []
    end
  end

  test "decodes to 1 byte" do
    assert {:ok, "TQ==", <<>>} = <<77>> |> decode(codec())
  end

  test "decodes to 2 bytes" do
    assert {:ok, "TWE=", <<>>} = <<77, 97>> |> decode(codec())
  end

  test "decodes to 3 bytes" do
    assert {:ok, "TWFu", <<>>} = <<77, 97, 110>> |> decode(codec())
  end

  test "encodes 1 byte" do
    assert {:ok, <<77>>} = "TQ==" |> encode(codec())
  end

  test "encodes 2 bytes" do
    assert {:ok, <<77, 97>>} = "TWE=" |> encode(codec())
  end

  test "encodes 3 bytes" do
    assert {:ok, <<77, 97, 110>>} = "TWFu" |> encode(codec())
  end

  # https://datatracker.ietf.org/doc/html/rfc4648#section-10
  test "RFC4648 test vectors" do
    assert {:ok, "", <<>>} = "" |> decode(codec())
    assert {:ok, ""} = "" |> encode(codec())

    assert {:ok, "Zg==", <<>>} = "f" |> decode(codec())
    assert {:ok, "f"} = "Zg==" |> encode(codec())

    assert {:ok, "Zm8=", <<>>} = "fo" |> decode(codec())
    assert {:ok, "fo"} = "Zm8=" |> encode(codec())

    assert {:ok, "Zm9v", <<>>} = "foo" |> decode(codec())
    assert {:ok, "foo"} = "Zm9v" |> encode(codec())

    assert {:ok, "Zm9vYg==", <<>>} = "foob" |> decode(codec())
    assert {:ok, "foob"} = "Zm9vYg==" |> encode(codec())

    assert {:ok, "Zm9vYmE=", <<>>} = "fooba" |> decode(codec())
    assert {:ok, "fooba"} = "Zm9vYmE=" |> encode(codec())

    assert {:ok, "Zm9vYmFy", <<>>} = "foobar" |> decode(codec())
    assert {:ok, "foobar"} = "Zm9vYmFy" |> encode(codec())
  end
end
