defmodule BinCodexTest do
  use ExUnit.Case

  defmodule Foo do
    defstruct a: nil, b: nil
  end

  doctest Bifrost, import: true

  test "greets the world" do
    assert :world == :world
  end
end
