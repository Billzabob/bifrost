defmodule Bifrost.Codecs.Varint do
  import Bifrost
  alias Bifrost.Util

  @spec codec() :: Bifrost.codec(non_neg_integer)
  def codec() do
    take_while(bool_bit(), bits(7))
    |> append(bits(7))
    |> reverse()
    |> convert(&Util.join(&1, 7), &Util.split(&1, 7))
  end
end
