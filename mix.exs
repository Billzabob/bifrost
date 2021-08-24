defmodule Bifrost.MixProject do
  use Mix.Project

  def project do
    [
      app: :bifrost,
      description: "Combinator library for working with binary data",
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        main: "Bifrost",
        canonical: "http://hexdocs.pm/bifrost",
        source_url: "https://github.com/Billzabob/bifrost"
      ]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:exprof, "~> 0.2.0"},
      {:stream_data, "~> 0.5", only: :test}
    ]
  end

  defp package() do
    [
      name: "bifrost",
      licenses: ["LGPL-3.0"],
      links: %{"GitHub" => "https://github.com/Billzabob/bifrost"}
    ]
  end
end
