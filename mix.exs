defmodule Nearex.MixProject do
  use Mix.Project

  def project do
    [
      app: :nearex,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nearex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:B58, "~> 1.0", hex: :b58},
      {:enacl, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.3"},
      {:hackney, "~> 1.16"},
      {:caustic, "~> 0.1.24"}
    ]
  end
end
