defmodule Apical.MixProject do
  use Mix.Project

  def project do
    [
      app: :apical,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:pegasus, "~> 0.2", runtime: false},
      {:exonerate, "~> 1.1.0", runtime: false},
      {:bandit, ">= 0.7.6", only: :test},
      {:phoenix, "~> 1.7.2", only: [:test, :dev]},
      {:phoenix_html, "~> 3.3.1", only: :test},
      {:yaml_elixir, "~> 2.7", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:plug, "~> 1.14"},
      {:json_ptr, "~> 1.2"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Apical",
      extra_section: "GUIDES",
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
      ],
      extras: []
    ]
  end
end
