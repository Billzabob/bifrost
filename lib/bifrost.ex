defmodule Bifrost do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Bifrost.Codec

  @type type :: any
  @type type2 :: any
  @type remaining_bits :: bitstring

  @type encode_result :: {:ok, bitstring} | {:error, String.t()}
  @type decode_result(a) :: {:ok, a, remaining_bits} | {:error, String.t(), remaining_bits}

  @type encoder(a) :: (a -> encode_result)
  @type decoder(a) :: (bitstring -> decode_result(a))

  @type codec(a) :: %Codec{encode: encoder(a), decode: decoder(a)}

  @type boolean_codec :: codec(boolean)
  @type list_codec(a) :: codec(list(a))

  @doc """
  Creates a new codec.

  It is recommended to use the other well-tested functions in the module to build a codec instead of creating your own unless you absolutely have to.

  When creating your own codec it *MUST* be idempotent.

  ## Examples
  ```
  iex> Bifrost.create(fn _ -> {:ok, <<>>} end, fn
  ...>   <<>> -> {:ok, false, <<>>}
  ...>   bits -> {:ok, true, bits}
  ...> end)
  #Bifrost.Codec<...>
  ```
  """
  @spec create(encoder(type), decoder(type)) :: %Codec{}
  def create(encode, decode) when is_function(encode, 1) and is_function(decode, 1),
    do: %Codec{encode: safe_encode(encode), decode: safe_decode(decode)}

  @doc """
  Encodes a value to its binary form using the supplied codec.

  ## Examples
  ```
  iex> 198 |> encode(byte())
  {:ok, <<198>>}
  ```
  """
  @spec encode(type, codec(type)) :: encode_result
  def encode(value, %Codec{encode: encode}) when is_function(encode, 1), do: encode.(value)
  def encode(_value, %Codec{encode: _encode}), do: nil

  @doc """
  Decodes a value from its binary form using the supplied codec.

  The third element of the tuple is any remaining unparsed bits.

  ## Examples
  ```
  iex> <<198>> |> decode(byte())
  {:ok, 198, <<>>}
  ```
  """
  @spec decode(bitstring, codec(type)) :: decode_result(type)
  def decode(bits, %Codec{decode: decode}) when is_function(decode, 1), do: decode.(bits)
  def decode(_bits, %Codec{decode: _decode}), do: nil

  @doc """
  Combines two codecs into a codec that produces a 2-element tuple of each value.

  ## Examples
  ```
  iex> {198, 2} |> encode(combine(byte(), byte()))
  {:ok, <<198, 2>>}

  iex> <<198, 2>> |> decode(combine(byte(), byte()))
  {:ok, {198, 2}, <<>>}
  ```
  """
  @spec combine(codec(type), codec(type2)) :: codec({type, type2})
  def combine(codec1, codec2),
    do: create(&combine_encoder(codec1, codec2, &1), &combine_decoder(codec1, codec2, &1))

  @doc """
  A codec that always encodes to and decodes from the same value.

  It fails if it doesn't see the expected value that it always encodes/decodes.

  ## Examples
  ```
  iex> <<200>> |> decode(constant(10, <<200>>))
  {:ok, 10, <<>>}

  iex> <<234>> |> decode(constant(10, <<200>>))
  {:error, "<<234>> did not equal <<200>> in constant", <<234>>}

  iex> 10 |> encode(constant(10, <<200>>))
  {:ok, <<200>>}

  iex> 22 |> encode(constant(10, <<200>>))
  {:error, "22 did not equal 10 in constant"}
  ```
  """
  @spec constant(type, bitstring) :: codec(type)
  def constant(value, bits),
    do: create(&constant_encoder(value, bits, &1), &constant_decoder(value, bits, &1))

  @doc """
  A codec that always decodes to a certain value.

  It never consumes bits while decoding so it can't fail. It can fail on encoding if the value to encode doesn't match.

  ## Examples
  ```
  iex> <<>> |> decode(value(10))
  {:ok, 10, <<>>}

  iex> <<200>> |> decode(value(10))
  {:ok, 10, <<200>>}

  iex> 10 |> encode(value(10))
  {:ok, <<>>}

  iex> 22 |> encode(value(10))
  {:error, "22 did not equal 10 in constant"}
  ```
  """
  @spec value(type) :: codec(type)
  def value(value), do: constant(value, <<>>)

  @doc """
  A codec that always decodes to an empty list, `[]`.

  It can never fail decoding.

  ## Examples
  ```
  iex> defmodule EmptyExample do
  ...>   def listify([]), do: empty()
  ...>   def listify([codec | rest]), do: codec |> cons(listify(rest))
  ...> end
  ...> <<1>> |> decode(EmptyExample.listify([]))
  {:ok, [], <<1>>}
  ...> <<22, 38>> |> decode(EmptyExample.listify([byte(), byte()]))
  {:ok, [22, 38], <<>>}
  ```
  """
  @spec empty() :: codec([])
  def empty(), do: value([])

  @doc """
  A codec that always decodes to `nil`.

  It can never fail decoding.

  ## Examples
  ```
  iex> optional_byte = byte() |> fallback(nothing())
  ...> <<8>> |> decode(optional_byte)
  {:ok, 8, <<>>}
  ...> <<8::4>> |> decode(optional_byte)
  {:ok, nil, <<8::4>>}
  ```
  """
  @spec nothing() :: codec(nil)
  def nothing(), do: value(nil)

  @doc """
  Uses the first codec, falling back to the second if it fails.

  ## Examples
  ```
  iex> optional_byte = byte() |> fallback(nothing())
  ...> <<8>> |> decode(optional_byte)
  {:ok, 8, <<>>}
  ...> <<8::4>> |> decode(optional_byte)
  {:ok, nil, <<8::4>>}
  ```
  """
  @spec fallback(codec(type), codec(type2)) :: codec(type | type2)
  def fallback(codec1, codec2),
    do: create(&fallback_encoder(codec1, codec2, &1), &fallback_decoder(codec1, codec2, &1))

  @doc """
  Creates a codec that always fails with the supplied error message.

  This is not useful on its own but can be useful when building other codecs.

  ## Examples
  ```
  iex> defmodule FailExample do
  ...>   def choose([]), do: fail("None of the choices worked")
  ...>   def choose([codec | rest]), do: fallback(codec, choice(rest))
  ...> end
  ...> codec = FailExample.choose([byte(), bits(4)])
  ...> <<1>> |> decode(codec)
  {:ok, 1, <<>>}
  ...> <<1::2>> |> decode(codec)
  {:error, "None of the choices worked", <<1::2>>}
  ```
  """
  @spec fail(String.t()) :: codec(any)
  def fail(error), do: fail(error, error)

  @doc """
  Creates a codec that always fails with the supplied error messages.

  Same as `fail/1` but you can supply a different error message for encoding and decoding.
  """
  @spec fail(String.t(), String.t()) :: codec(any)
  def fail(encode_error, decode_error),
    do: create(fn _ -> {:error, encode_error} end, fn bits -> {:error, decode_error, bits} end)

  @doc """
  Tries to encode/decode each codec in succession, using the first one that succeeds.

  ## Examples
  ```
  iex> <<1>> |> decode(choice([byte(), bits(4)]))
  {:ok, 1, <<>>}

  iex> <<1::4>> |> decode(choice([byte(), bits(4)]))
  {:ok, 1, <<>>}

  iex> <<1::2>> |> decode(choice([byte(), bits(4)]))
  {:error, "None of the choices worked", <<1::2>>}
  ```
  """
  @spec choice([codec(type)]) :: codec(type)
  def choice([]), do: fail("None of the choices worked")
  def choice([codec | rest]), do: codec |> fallback(choice(rest))

  @doc """
  Creates a codec that might not work. If it fails decoding it returns `nil` instead.

  ## Examples
  ```
  iex> <<11>> |> decode(optional(byte()))
  {:ok, 11, <<>>}

  iex> <<1::4>> |> decode(optional(byte()))
  {:ok, nil, <<1::4>>}
  ```
  """
  @spec optional(codec(type)) :: codec(type | nil)
  def optional(codec), do: fallback(codec, nothing())

  @doc """
  Creates a codec that decodes without actually consuming the bits.

  ## Examples
  ```
  iex> <<4>> |> decode(peek(byte()))
  {:ok, 4, <<4>>}

  iex> codec = peek(byte()) |> combine(byte())
  ...> <<4>> |> decode(codec)
  {:ok, {4, 4}, <<>>}
  ...> {4, 4} |> encode(codec)
  {:ok, <<4>>}
  ```
  """
  @spec peek(codec(type)) :: codec(type)
  def peek(codec) do
    decode = fn bits ->
      with {:ok, a, _remaining} <- codec.decode.(bits) do
        {:ok, a, bits}
      end
    end

    create(fn _ -> {:ok, <<>>} end, decode)
  end

  @doc """
  Used to convert a codec to another type.

  Must also be used with caution to make sure your conversion is idempotent.

  ## Examples
  ```
  defmodule Foo do
    defstruct a: nil, b: nil
  end

  iex> tuple_codec = combine(byte(), byte())
  ...> struct_codec = tuple_codec |> convert(fn {a, b} -> %Foo{a: a, b: b} end, fn %Foo{a: a, b: b} -> {a, b} end)
  ...> <<12, 34>> |> decode(struct_codec)
  {:ok, %Foo{a: 12, b: 34}, <<>>}
  ...> %Foo{a: 12, b: 34} |> encode(struct_codec)
  {:ok, <<12, 34>>}
  ```
  """
  @spec convert(codec(type), (type -> type2), (type2 -> type)) :: codec(type2)
  def convert(codec, convert_to, convert_from),
    do: create(&convert_encoder(codec, convert_from, &1), &convert_decoder(codec, convert_to, &1))

  @spec not_(boolean_codec()) :: boolean_codec()
  def not_(boolean_codec), do: boolean_codec |> convert(&!/1, &!/1)

  @doc """
  Use the result of a codec to create the next codec.

  ## Examples
  ```
  iex> length = byte()
  ...> length_prefixed = length |> then(&list_of(&1, byte()), &length/1)
  ...> <<4, 1, 2, 3, 4>> |> decode(length_prefixed)
  {:ok, [1, 2, 3, 4], <<>>}
  ...> [1, 2, 3, 4] |> encode(length_prefixed)
  {:ok, <<4, 1, 2, 3, 4>>}
  ```
  """
  @spec then(codec(type), (type -> codec(type2)), (type2 -> type)) :: codec(type2)
  def then(codec, f, g),
    do: create(&then_encoder(codec, f, g, &1), &then_decoder(codec, f, &1))

  @doc """
  Fails a codec if the result doesn't satisfy the predicate.

  ## Examples
  ```
  iex> codec = byte() |> ensure(& &1 > 10, "Must be greater than 10")
  ...> 5 |> encode(codec)
  {:error, "Must be greater than 10"}
  ...> 11 |> encode(codec)
  {:ok, <<11>>}
  ...> <<5>> |> decode(codec)
  {:error, "Must be greater than 10"}
  ...> <<11>> |> decode(codec)
  {:ok, 11, <<>>}
  ```
  """
  @spec ensure(codec(type), (type -> boolean), String.t()) :: codec(type)
  def ensure(codec, predicate, error) do
    codec
    |> then(
      fn a -> if predicate.(a), do: value(a), else: fail(error) end,
      fn a -> a end
    )
  end

  @doc """
  Fails a codec if the result satisfies the predicate.

  ## Examples
  ```
  iex> codec = byte() |> refute(& &1 > 10, "Can't be greater than 10")
  ...> 11 |> encode(codec)
  {:error, "Can't be greater than 10"}
  ...> 5 |> encode(codec)
  {:ok, <<5>>}
  ...> <<11>> |> decode(codec)
  {:error, "Can't be greater than 10"}
  ...> <<5>> |> decode(codec)
  {:ok, 5, <<>>}
  ```
  """
  @spec refute(codec(type), (type -> boolean), String.t()) :: codec(type)
  def refute(codec, predicate, error), do: ensure(codec, &(!predicate.(&1)), error)

  @spec bits_remaining() :: boolean_codec()
  def bits_remaining() do
    create(fn _ -> {:ok, <<>>} end, fn
      <<>> -> {:ok, false, <<>>}
      bits -> {:ok, true, bits}
    end)
  end

  @doc """
  Only succeeds if there were no bits left to parse.

  ## Examples
  ```
  iex> <<10>> |> decode(byte() |> done())
  {:ok, 10, <<>>}

  iex> <<10, 11>> |> decode(byte() |> done())
  {:error, "There was more to parse", <<11>>}
  ```
  """
  @spec done(codec(type)) :: codec(type)
  def done(codec) do
    codec
    |> combine(bits_remaining())
    |> then(
      fn
        {_a, true} -> fail("There was more to parse")
        {a, false} -> value(a)
      end,
      fn a -> {a, false} end
    )
  end

  @doc """
  Uses the two mapping functions to convert each element of a list codec.

  ## Examples
  ```
  iex> codec = list(byte()) |> map_list(& &1 + 1, & &1 - 1)
  ...> <<10, 11, 12>> |> decode(codec)
  {:ok, [11, 12, 13], <<>>}
  ...> [11, 12, 13] |> encode(codec)
  {:ok, <<10, 11, 12>>}
  ```
  """
  @spec map_list(list_codec(type), (type -> type2), (type2 -> type)) :: list_codec(type2)
  def map_list(codec, map, map_back),
    do: codec |> convert(&Enum.map(&1, map), &Enum.map(&1, map_back))

  @doc """
  Reverses a list codec.

  ## Examples
  ```
  iex> codec = list(byte()) |> reverse()
  ...> [1, 2, 3] |> encode(codec)
  {:ok, <<3, 2, 1>>}
  ...> <<3, 2, 1>> |> decode(codec)
  {:ok, [1, 2, 3], <<>>}
  ```
  """
  @spec reverse(list_codec(type)) :: list_codec(type)
  def reverse(list_codec), do: list_codec |> convert(&Enum.reverse/1, &Enum.reverse/1)

  @doc """
  Combines a codec with a list codec to form a new list.

  ## Examples
  ```
  iex> non_empty_list = byte() |> cons(list(byte()))
  ...> [1] |> encode(non_empty_list)
  {:ok, <<1>>}
  ...> [] |> encode(non_empty_list)
  {:error, "Failed to encode []"}
  ...> <<1>> |> decode(non_empty_list)
  {:ok, [1], <<>>}
  ...> <<>> |> decode(non_empty_list)
  {:error, "Could not decode 8 bits from \\"\\"", <<>>}
  ```
  """
  @spec cons(codec(type), list_codec(type)) :: list_codec(type)
  def cons(codec, list_codec) do
    codec
    |> combine(list_codec)
    |> convert(
      fn {head, rest} -> [head | rest] end,
      fn [head | rest] -> {head, rest} end
    )
  end

  @doc """
  Appends a list codec with a codec to form a new list.

  ## Examples
  ```
  iex> codec = list_of(3, byte()) |> append(bits(4))
  ...> [1, 2, 3, 4] |> encode(codec)
  {:ok, <<1, 2, 3, 4::4>>}
  ...> <<1, 2, 3, 4::4>> |> decode(codec)
  {:ok, [1, 2, 3, 4], <<>>}
  ```
  """
  @spec append(list_codec(type), codec(type)) :: list_codec(type)
  def append(list_codec, codec) do
    list_codec
    |> combine(codec)
    |> convert(
      fn {list, a} -> list ++ [a] end,
      fn list ->
        [head | list] = Enum.reverse(list)
        {list, head}
      end
    )
  end

  @doc """
  Combines a list of codecs into a single codec that produces a list of those values.

  ## Examples
  ```
  iex> codec = sequence([byte(), byte(), byte()])
  ...> <<0x10, 0xFF, 0xAB>> |> decode(codec)
  {:ok, [16, 255, 171], <<>>}
  ...> [16, 255, 171] |> encode(codec)
  {:ok, <<0x10, 0xFF, 0xAB>>}
  ```
  """
  @spec sequence([codec(type)]) :: list_codec(type)
  def sequence([]), do: empty()
  def sequence([codec | rest]), do: codec |> cons(sequence(rest))

  @doc """
  Keeps accumulating `codec` in a list while `boolean_codec` evaluates to true.

  ## Examples
  ```
  iex> codec = take_while(bool_bit(), byte())
  ...> <<1::1, 7, 1::1, 8, 0::1>> |> decode(codec)
  {:ok, [7, 8], <<>>}
  ...> [7, 8] |> encode(codec)
  {:ok, <<1::1, 7, 1::1, 8, 0::1>>}
  ```
  """
  @spec take_while(boolean_codec, codec(type)) :: list_codec(type)
  def take_while(boolean_codec, codec) do
    boolean_codec
    |> then(
      fn
        true -> codec |> cons(take_while(boolean_codec, codec))
        false -> empty()
      end,
      fn
        [] -> false
        _ -> true
      end
    )
  end

  @doc """
  Keeps accumulating `codec` in a list until `boolean_codec` evaluates to true.

  ## Examples
  ```
  iex> codec = take_until(bool_bit(), byte())
  ...> <<0::1, 7, 0::1, 8, 1::1>> |> decode(codec)
  {:ok, [7, 8], <<>>}
  ...> [7, 8] |> encode(codec)
  {:ok, <<0::1, 7, 0::1, 8, 1::1>>}
  ```
  """
  @spec take_until(boolean_codec, codec(type)) :: list_codec(type)
  def take_until(boolean_codec, codec), do: take_while(not_(boolean_codec), codec)

  @doc """
  Repeatedly evaluates `codec` and accumulates the result into a list.

  ## Examples
  ```
  iex> [1, 2, 3, 4] |> encode(list(byte()))
  {:ok, <<1, 2, 3, 4>>}

  iex> [] |> encode(list(byte()))
  {:ok, <<>>}

  iex> <<>> |> decode(list(byte()))
  {:ok, [], <<>>}
  ```
  """
  @spec list(codec(type)) :: list_codec(type)
  def list(codec), do: take_while(bits_remaining(), codec)

  @doc """
  Decodes a list of `codec` of length `count`.

  ## Examples
  ```
  iex> [1, 2, 3, 4] |> encode(list_of(4, byte()))
  {:ok, <<1, 2, 3, 4>>}

  iex> <<1, 2, 3, 4, 5>> |> decode(list_of(4, byte()))
  {:ok, [1, 2, 3, 4], <<5>>}
  ```
  """
  @spec list_of(non_neg_integer, codec(type)) :: list_codec(type)
  def list_of(count, codec) when is_integer(count) and count >= 0,
    do: List.duplicate(codec, count) |> sequence()

  def list_of(count, _codec) when is_integer(count), do: raise("list_of count must be >= 0")

  @doc """
  Repeatedly evaluates `codec` and accumulates the result into a list.

  Fails if it doesn't successfully evaluate `codec` at least once.

  ## Examples
  ```
  iex> [1, 2, 3, 4] |> encode(non_empty_list(byte()))
  {:ok, <<1, 2, 3, 4>>}

  iex> [] |> encode(non_empty_list(byte()))
  {:error, "Failed to encode []"}

  iex> <<1, 2, 3, 4>> |> decode(non_empty_list(byte()))
  {:ok, [1, 2, 3, 4], <<>>}

  iex> <<>> |> decode(non_empty_list(byte()))
  {:error, "Could not decode 8 bits from \\"\\"", <<>>}
  ```
  """
  @spec non_empty_list(codec(type)) :: codec(nonempty_list(type))
  def non_empty_list(codec), do: codec |> cons(list(codec))

  @doc """
  Uses `length_codec` to determine the number of `codec` to evaluate as a list.

  ## Examples
  ```
  iex> [1, 2, 3, 4] |> encode(length_prefixed(byte(), byte()))
  {:ok, <<4, 1, 2, 3, 4>>}

  iex> <<4, 1, 2, 3, 4>> |> decode(length_prefixed(byte(), byte()))
  {:ok, [1, 2, 3, 4], <<>>}
  ```
  """
  @spec length_prefixed(codec(non_neg_integer), codec(type)) :: list_codec(type)
  def length_prefixed(length_codec, codec),
    do: length_codec |> then(&list_of(&1, codec), &length/1)

  @spec join(list_codec(binary), pos_integer) :: codec(binary)
  def join(codec, group_size \\ 1), do: codec |> convert(&Enum.join/1, &split_by(&1, group_size))

  @doc """
  Uses a map to convert a codecs results.

  The map *MUST NOT* have duplicate values or converting back becomes ambiguous.

  ## Examples
  ```
  iex> codec = list(byte() |> mapping(%{1 => "a", 2 => "b", 3 => "c"}))
  ...> <<1, 2, 3>> |> decode(codec)
  {:ok, ["a", "b", "c"], <<>>}
  ...> ["a", "b", "c"] |> encode(codec)
  {:ok, <<1, 2, 3>>}
  ```
  """
  @spec mapping(codec(type), %{type => type2}) :: codec(type2)
  def mapping(codec, mapping) when is_map(mapping) do
    map_back = mapping |> Enum.map(fn {k, v} -> {v, k} end) |> Enum.into(%{})
    codec |> convert(&Map.fetch!(mapping, &1), &Map.fetch!(map_back, &1))
  end

  @doc """
  Encodes/decodes a single bit as either 0 or 1.

  ## Examples
  ```
  iex> <<1::1>> |> decode(bit())
  {:ok, 1, <<>>}

  iex> <<0::1>> |> decode(bit())
  {:ok, 0, <<>>}

  iex> 1 |> encode(bit())
  {:ok, <<1::1>>}

  iex> 0 |> encode(bit())
  {:ok, <<0::1>>}

  iex> 2 |> encode(bit())
  {:error, "2 cannot be encoded in 1 bits"}
  ```
  """
  @spec bit() :: codec(0 | 1)
  def bit(), do: bits(1)

  @doc """
  Encodes/decodes a series of bits as an unsigned integer.

  ## Examples
  ```
  iex> <<3::7>> |> decode(bits(7))
  {:ok, 3, <<>>}

  iex> 5 |> encode(bits(7))
  {:ok, <<5::7>>}

  iex> 300 |> encode(bits(7))
  {:error, "300 cannot be encoded in 7 bits"}
  ```
  """
  @spec bits(non_neg_integer) :: codec(non_neg_integer)
  def bits(count), do: create(&bits_encoder(count, &1), &bits_decoder(count, &1))

  @doc """
  Pads the bitstring before decoding.

  ## Examples
  ```
  iex> <<1::1>> |> decode(bit() |> pad(2))
  {:ok, 4, <<>>}

  # It's as if you padded it with two zero bits on the right:
  iex> <<1::1, 0::1, 0::1>> |> decode(bits(3))
  {:ok, 4, <<>>}

  iex> 4 |> encode(bit() |> pad(2))
  {:ok, <<1::1>>}
  ```
  """
  @spec pad(codec(type), non_neg_integer) :: codec(type)
  def pad(codec, bits) do
    use Bitwise
    codec |> convert(&(&1 <<< bits), &(&1 >>> bits))
  end

  @doc """
  Encodes/decodes a single bit as either true (if 1) or false (if 0).

  ## Examples
  ```
  iex> <<1::1>> |> decode(bool_bit())
  {:ok, true, <<>>}

  iex> <<0::1>> |> decode(bool_bit())
  {:ok, false, <<>>}

  iex> true |> encode(bool_bit())
  {:ok, <<1::1>>}

  iex> false |> encode(bool_bit())
  {:ok, <<0::1>>}
  ```
  """
  @spec bool_bit() :: boolean_codec()
  def bool_bit() do
    bit()
    |> convert(
      fn
        1 -> true
        0 -> false
      end,
      fn
        true -> 1
        false -> 0
      end
    )
  end

  @doc """
  Encodes/decodes a single byte as an unsigned integer.

  ## Examples
  ```
  iex> <<123>> |> decode(byte())
  {:ok, 123, <<>>}

  iex> 210 |> encode(byte())
  {:ok, <<210>>}

  iex> 400 |> encode(byte())
  {:error, "400 cannot be encoded in 8 bits"}
  ```
  """
  @spec byte() :: codec(non_neg_integer)
  def byte(), do: bytes(1)

  @doc """
  Encodes/decodes a series of bytes as an unsigned integer.

  ## Examples
  ```
  iex> <<1, 2>> |> decode(bytes(2))
  {:ok, 258, <<>>}

  iex> 258 |> encode(bytes(2))
  {:ok, <<1, 2>>}
  ```
  """
  @spec bytes(non_neg_integer) :: codec(non_neg_integer)
  def bytes(count), do: bits(count * 8)

  defp safe_encode(encode) do
    fn a ->
      try do
        encode.(a)
      rescue
        _ -> {:error, "Failed to encode #{inspect(a)}"}
      end
    end
  end

  defp safe_decode(decode) do
    fn bits ->
      try do
        decode.(bits)
      rescue
        _ -> {:error, "Failed to decode #{inspect(bits)}"}
      end
    end
  end

  defp split_by(binary, group_size),
    do: binary |> String.codepoints() |> Enum.chunk_every(group_size) |> Enum.map(&Enum.join/1)

  defp bits_encoder(count, _n) when count <= 0, do: raise("count must be >= 0, was #{count}")

  defp bits_encoder(_count, n) when is_integer(n) and n < 0,
    do: {:error, "Cannot encode negative number #{n}"}

  defp bits_encoder(count, n) when is_integer(n) do
    if(n < Integer.pow(2, count),
      do: {:ok, <<n::size(count)>>},
      else: {:error, "#{n} cannot be encoded in #{count} bits"}
    )
  end

  defp bits_encoder(_count, other), do: {:error, "'#{inspect(other)}' is not a positive integer"}

  defp bits_decoder(count, bits) do
    case bits do
      <<n::size(count), rest::bits>> -> {:ok, n, rest}
      bits -> {:error, "Could not decode #{count} bits from #{inspect(bits)}", bits}
    end
  end

  defp combine_encoder(codec1, codec2, {a, b}) do
    with {:ok, a_bits} <- codec1.encode.(a),
         {:ok, b_bits} <- codec2.encode.(b) do
      {:ok, <<a_bits::bits, b_bits::bits>>}
    end
  end

  defp combine_decoder(codec1, codec2, bits) do
    with {:ok, a, bits} <- codec1.decode.(bits),
         {:ok, b, bits} <- codec2.decode.(bits) do
      {:ok, {a, b}, bits}
    end
  end

  defp constant_encoder(value, bits, a) do
    case a do
      ^value -> {:ok, bits}
      other -> {:error, "#{inspect(other)} did not equal #{inspect(value)} in constant"}
    end
  end

  defp constant_decoder(value, bits, b) do
    size = bit_size(bits)

    case b do
      <<b::size(size), rest::bits>> when <<b::size(size)>> == bits -> {:ok, value, rest}
      other -> {:error, "#{inspect(other)} did not equal #{inspect(bits)} in constant", other}
    end
  end

  defp convert_encoder(codec, convert_from, a), do: a |> convert_from.() |> codec.encode.()

  defp convert_decoder(codec, convert_to, a) do
    with {:ok, a, bits} <- codec.decode.(a) do
      {:ok, convert_to.(a), bits}
    end
  end

  defp then_encoder(codec, f, g, a) do
    prefix = g.(a)

    with {:ok, a_bits} <- codec.encode.(prefix),
         {:ok, b_bits} <- f.(prefix).encode.(a) do
      {:ok, <<a_bits::bits, b_bits::bits>>}
    end
  end

  defp then_decoder(codec, f, bits) do
    with {:ok, a, rest} <- codec.decode.(bits) do
      f.(a).decode.(rest)
    end
  end

  defp fallback_encoder(codec1, codec2, a) do
    with {:error, _} <- codec1.encode.(a) do
      codec2.encode.(a)
    end
  end

  defp fallback_decoder(codec1, codec2, bits) do
    with {:error, _, _} <- codec1.decode.(bits) do
      codec2.decode.(bits)
    end
  end
end
