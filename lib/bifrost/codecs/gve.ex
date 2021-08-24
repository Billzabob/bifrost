defmodule Bifrost.Codecs.Gve do
  import Bifrost

  @spec codec() :: Bifrost.codec(list(non_neg_integer))
  def codec() do
    list_of(4, bits(2))
    |> then(
      fn lengths -> Enum.map(lengths, &uint(8 * &1)) |> sequence() end,
      fn numbers -> Enum.map(numbers, &size_in_bytes/1) end
    )
  end

  defp size_in_bytes(integer), do: integer |> :binary.encode_unsigned() |> byte_size()
end
