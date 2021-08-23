# Bifrost

## [![Hex pm](http://img.shields.io/hexpm/v/bifrost.svg?style=flat)](https://hex.pm/packages/bifrost) [![Hex Docs](https://img.shields.io/badge/hex-docs-9768d1.svg)](https://hexdocs.pm/bifrost)

<!-- MDOC !-->

Provides functions to create composable and bidirectional serializers.

## Installation

```elixir
def deps do
  [
    {:bifrost, "~> 0.1.0"}
  ]
end
```

## Usage

The `Bifrost` module provides a number of predefined codecs and combinators that you can use to build new codes.
```elixir
iex> first_codec = sequence([byte(), byte(), byte()])
...> <<0x10, 0xFF, 0xAB>> |> decode(first_codec)
{:ok, [16, 255, 171], <<>>}
...> [16, 255, 171] |> encode(first_codec)
{:ok, <<0x10, 0xFF, 0xAB>>}
```

## Inspiration

This library draws inspiration from https://github.com/scodec/scodec