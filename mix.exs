defmodule Apical.MixProject do
  use Mix.Project

  def project do
    [
      app: :apical,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
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
      {:exonerate, "~> 0.3.2", runtime: false},
      {:bandit, ">= 0.7.6", only: :test},
      {:phoenix, "~> 1.7.2", only: :test},
      {:phoenix_html, "~> 3.3.1", only: :test},
      {:yaml_elixir, "~> 2.7", optional: true},
      {:jason, "~> 1.4", optional: true}
    ]
  end
end
