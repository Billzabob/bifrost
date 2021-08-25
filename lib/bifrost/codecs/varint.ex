defmodule Bifrost.Codecs.Varint do
  import Bifrost

  @segment_size 7

  @spec codec() :: Bifrost.codec(non_neg_integer)
  def codec() do
    take_while(bool(), bits(@segment_size))
    |> append(bits(@segment_size))
    |> reverse()
    |> join(@segment_size)
    |> convert(&bits_to_int/1, fn uint -> uint |> int_to_bits() |> pad_to(@segment_size) end)
  end

  defp bits_to_int(bits) do
    b = bit_size(bits)
    <<x::size(b)>> = bits
    x
  end

  defp int_to_bits(uint), do: :binary.encode_unsigned(uint) |> remove_leading_zeros()

  defp pad_to(bits, count) do
    padding = count - rem(bit_size(bits), count)
    <<0::size(padding), bits::bits>>
  end

  defp remove_leading_zeros(<<0::1, bits::bits>>), do: remove_leading_zeros(bits)
  defp remove_leading_zeros(bits), do: bits
end
