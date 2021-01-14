defmodule Quarto.MixProject do
  use Mix.Project

  @url "https://github.com/maartenvanvliet/quarto"
  def project do
    [
      app: :quarto,
      version: "1.1.5",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      source_url: @url,
      homepage_url: @url,
      name: "Quarto",
      description: "Quarto is a keyset-based (cursor-based) pagination library for Ecto.",
      package: [
        maintainers: ["Maarten van Vliet"],
        licenses: ["MIT"],
        links: %{"GitHub" => @url},
        files: ~w(LICENSE README.md lib mix.exs)
      ],
      docs: [
        main: "Quarto",
        canonical: "http://hexdocs.pm/quarto",
        source_url: @url
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.4"},
      {:postgrex, "~> 0.14", only: :test},
      {:ex_doc, "~> 0.21", only: [:dev, :test]},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:plug_crypto, "~> 1.1.2 or ~> 1.2"}
    ]
  end
end
