defmodule Bifrost.Profile do
  import ExProf.Macro
  import Bifrost

  def run() do
    codec = Bifrost.Codecs.Base.Base64.codec()
    binary = Enum.to_list(1..10_000) |> Enum.map(&rem(&1, 256)) |> :binary.list_to_bin()

    profile do
      binary |> decode(codec)
    end
  end
end

Bifrost.Profile.run()
