defmodule Bifrost.Codecs.Base.Base32 do
  @moduledoc """
  Base32 codec implemented using Bifrost combinators.

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "MZXW6YTBOI======", <<>>}

  iex> "MZXW6YTBOI======" |> encode(codec())
  {:ok, "foobar"}
  ```
  """

  import Bifrost

  @capitals 65..90 |> Enum.map(&:binary.encode_unsigned/1)
  @numbers 50..55 |> Enum.map(&:binary.encode_unsigned/1)

  @num_to_char (@capitals ++ @numbers)
               |> Enum.with_index()
               |> Enum.map(fn {char, num} -> {num, char} end)
               |> Enum.into(%{})

  @doc """
  Builds a codec for Base32 encoding/decoding

  ```
  iex> "foobar" |> decode(codec())
  {:ok, "MZXW6YTBOI======", <<>>}

  iex> "MZXW6YTBOI======" |> encode(codec())
  {:ok, "foobar"}
  ```
  """
  @spec codec() :: Bifrost.codec(String.t())
  def codec() do
    char_4 = bits(4) |> done() |> pad(1) |> mapping(@num_to_char)
    char_3 = bits(3) |> done() |> pad(2) |> mapping(@num_to_char)
    char_2 = bits(2) |> done() |> pad(3) |> mapping(@num_to_char)
    char_1 = bits(1) |> done() |> pad(4) |> mapping(@num_to_char)

    list(
      choice(
        [
          char(8),
          char(1) ++ [char_3] ++ padding(6),
          char(3) ++ [char_1] ++ padding(4),
          char(4) ++ [char_4] ++ padding(3),
          char(6) ++ [char_2] ++ padding(1)
        ]
        |> Enum.map(&(&1 |> sequence() |> join()))
      )
    )
    |> join(8)
  end

  defp padding(count), do: List.duplicate(value("="), count)
  defp char(count), do: List.duplicate(bits(5) |> mapping(@num_to_char), count)
end
