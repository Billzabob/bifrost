inputs = %{
  "small" => Enum.to_list(1..100) |> Enum.map(&rem(&1, 256)) |> :binary.list_to_bin |> Base.encode64(),
  "medium" => Enum.to_list(1..10_000) |> Enum.map(&rem(&1, 256)) |> :binary.list_to_bin |> Base.encode64()
  # "large" => Enum.to_list(1..1_000_000) |> Enum.map(&rem(&1, 256)) |> :binary.list_to_bin |> Base.encode64()
}

codec = Bifrost.Codecs.Base.Base64.codec()

Benchee.run(
  %{
    "Bifrost" => fn binary -> binary |> Bifrost.encode(codec) end,
    "Base" => fn binary -> Base.decode64(binary) end
  },
  inputs: inputs
)
