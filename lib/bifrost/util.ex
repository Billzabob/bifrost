defmodule Bifrost.Util do
  @spec reverse_bits(bitstring) :: bitstring
  def reverse_bits(<<>>), do: <<>>

  def reverse_bits(<<x::1, rest::bits>>) do
    a = reverse_bits(rest)
    <<a::bits, x::1>>
  end

  @spec bits_to_int(bitstring) :: non_neg_integer
  def bits_to_int(bits) do
    b = bit_size(bits)
    <<x::size(b)>> = bits
    x
  end

  @spec remove_leading_zeros(bitstring) :: bitstring
  def remove_leading_zeros(<<0::1, bits::bits>>), do: remove_leading_zeros(bits)
  def remove_leading_zeros(bits), do: bits

  @spec split(non_neg_integer, non_neg_integer) :: list(non_neg_integer)
  def split(int, bit_size) do
    int
    |> :binary.encode_unsigned()
    |> remove_leading_zeros()
    |> reverse_bits()
    |> do_split(bit_size)
    |> Enum.reverse()
    |> Stream.map(&reverse_bits/1)
    |> Enum.map(&bits_to_int/1)
  end

  @spec join(list(non_neg_integer), non_neg_integer) :: non_neg_integer
  def join(ints, bit_size) do
    ints
    |> Stream.map(fn n -> <<n::size(bit_size)>> end)
    |> Enum.into(<<>>)
    |> bits_to_int()
  end

  defp do_split(<<>>, _split_size), do: []

  defp do_split(bits, bit_size) do
    case bits do
      <<n::size(bit_size)-bits, rest::bits>> -> [n | do_split(rest, bit_size)]
      other -> [other]
    end
  end
end
