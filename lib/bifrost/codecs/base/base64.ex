defmodule Bifrost.Codecs.Base.Base64 do
  @moduledoc """
  Base64 codec implemented using Bifrost combinators.

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "Zm9vYmFy", <<>>}

  iex> "Zm9vYmFy" |> encode(codec())
  {:ok, "foobar"}
  ```
  """

  import Bifrost

  @capitals ?A..?Z |> Enum.map(&:binary.encode_unsigned/1)
  @lowers ?a..?z |> Enum.map(&:binary.encode_unsigned/1)
  @numbers ?0..?9 |> Enum.map(&:binary.encode_unsigned/1)

  @num_to_char (@capitals ++ @lowers ++ @numbers ++ ["+", "/"])
               |> Enum.with_index()
               |> Enum.map(fn {char, num} -> {<<num::6>>, char} end)
               |> Enum.into(%{})

  @doc """
  Builds a codec for Base64 encoding/decoding

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "Zm9vYmFy", <<>>}

  iex> "Zm9vYmFy" |> encode(codec())
  {:ok, "foobar"}
  ```
  """
  @spec codec() :: Bifrost.codec(String.t())
  def codec() do
    char_2 = bits(2) |> done() |> pad(4) |> mapping(@num_to_char)
    char_4 = bits(4) |> done() |> pad(2) |> mapping(@num_to_char)

    list(
      choice(
        [
          char(4),
          char(1) ++ [char_2] ++ padding(2),
          char(2) ++ [char_4] ++ padding(1)
        ]
        |> Enum.map(&(&1 |> sequence() |> join()))
      )
    )
    |> join(32)
  end

  defp padding(count), do: List.duplicate(value("="), count)
  defp char(count), do: List.duplicate(bits(6) |> mapping(@num_to_char), count)
end
