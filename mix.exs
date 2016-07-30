defmodule Esq.Mixfile do
  use Mix.Project

  def project do
    [app: :esq,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :poolboy, :httpoison],
     mod: {Esq.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
     {:ex_aws,  "~> 0.4.13"},
     {:poolboy, "~> 1.5"},
     {:poison, "~> 2.0"},
     {:httpoison, "~> 0.9.0"},
     {:uuid, "~> 1.1"},
    ]
  end
end
