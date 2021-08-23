defmodule Bifrost.Codec do
  @derive {Inspect, except: [:encode, :decode]}
  defstruct encode: nil, decode: nil
end
