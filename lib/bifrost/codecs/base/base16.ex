defmodule Bifrost.Codecs.Base.Base16 do
  @moduledoc """
  Base16 (hex) codec implemented using Bifrost combinators.

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "666F6F626172", <<>>}

  iex> "666F6F626172" |> encode(codec())
  {:ok, "foobar"}
  ```
  """

  import Bifrost

  @numbers ?0..?9 |> Enum.map(&:binary.encode_unsigned/1)
  @capitals ?A..?F |> Enum.map(&:binary.encode_unsigned/1)

  @num_to_char (@numbers ++ @capitals)
               |> Enum.with_index()
               |> Enum.map(fn {char, num} -> {<<num::4>>, char} end)
               |> Enum.into(%{})

  @doc """
  Builds a codec for Base16 (hex) encoding/decoding

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "666F6F626172", <<>>}

  iex> "666F6F626172" |> encode(codec())
  {:ok, "foobar"}
  ```
  """
  @spec codec() :: Bifrost.codec(String.t())
  def codec(), do: list(list_of(2, bits(4) |> mapping(@num_to_char)) |> join()) |> join(16)
end
