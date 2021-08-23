defmodule Bifrost.Codecs.Base.Base16 do
  import Bifrost

  @numbers 48..57 |> Enum.map(&:binary.encode_unsigned/1)
  @capitals 65..70 |> Enum.map(&:binary.encode_unsigned/1)

  @num_to_char (@numbers ++ @capitals)
               |> Enum.with_index()
               |> Enum.map(fn {char, num} -> {num, char} end)
               |> Enum.into(%{})

  @spec codec() :: Bifrost.codec(String.t())
  def codec(), do: list(list_of(2, bits(4) |> mapping(@num_to_char)) |> join()) |> join(2)
end
