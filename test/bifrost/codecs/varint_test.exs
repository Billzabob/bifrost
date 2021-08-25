defmodule Bifrost.Codecs.VarintTest do
  use ExUnit.Case
  import Bifrost
  import Bifrost.Codecs.Varint

  doctest Bifrost.Codecs.Varint

  test "foo" do
    assert {:ok, 130, <<>>} = <<0x82, 0x01>> |> decode(codec())
  end

  test "bar" do
    assert {:ok, <<0x82, 0x01>>} = 130 |> encode(codec())
  end
end
