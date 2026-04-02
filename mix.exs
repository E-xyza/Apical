defmodule Apical.MixProject do
  use Mix.Project

  def project do
    [
      app: :apical,
      version: "0.3.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: [
        description: "OpenAPI 3.1.0 router generator for Elixir",
        licenses: ["MIT"],
        files: ~w(lib mix.exs README* LICENSE* CHANGELOG*),
        links: %{"GitHub" => "https://github.com/E-xyza/Apical"}
      ],
      source_url: "https://github.com/E-xyza/Apical/",
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def elixirc_paths(:test), do: ["lib", "test/_support"]
  def elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:pegasus, "~> 1.0", runtime: false},
      {:exonerate, "~> 1.2", runtime: false},
      {:bandit, "~> 1.6", only: :test},
      # note that phoenix is an optional dependency.
      {:phoenix, "~> 1.7", only: [:test, :dev], optional: true},
      {:phoenix_html, "~> 4.1", only: :test, optional: true},
      {:req, "~> 0.5", only: :test},
      {:yaml_elixir, "~> 2.9", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:mox, "~> 1.1", optional: true},
      {:bypass, "~> 2.1", optional: true},
      {:plug, "~> 1.19"},
      {:json_ptr, "~> 1.2"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Apical",
      source_ref: "main",
      extra_section: "GUIDES",
      extras: [
        "guides/Getting Started.md",
        "guides/Parameter Validation.md",
        "guides/Request Body Handling.md",
        "guides/Remote References.md",
        "guides/Apical for testing.md"
      ],
      groups_for_modules: [
        Behaviours: [
          Apical.Plugs.RequestBody.Source
        ],
        Plugs: [
          Apical.Plugs.Cookie,
          Apical.Plugs.Header,
          Apical.Plugs.Path,
          Apical.Plugs.Query,
          Apical.Plugs.RequestBody,
          Apical.Plugs.SetOperationId,
          Apical.Plugs.SetVersion
        ],
        "RequestBody Source Plugins": [
          Apical.Plugs.RequestBody.Default,
          Apical.Plugs.RequestBody.Json,
          Apical.Plugs.RequestBody.FormEncoded
        ]
      ]
    ]
  end
end
