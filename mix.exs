defmodule Avrogen.MixProject do
  use Mix.Project

  @version "0.10.0"
  @source_url "https://github.com/primait/avrogen"

  def project do
    [
      app: :avrogen,
      version: @version,
      source_url: @source_url,
      homepage_url: @source_url,
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:accessible, "~> 0.3"},
      {:credo, "== 1.7.1", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:erlavro, "~> 2.9"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excribe, "~> 0.1"},
      {:jason, "~> 1.0"},
      {:libgraph, "~> 0.16"},
      {:timex, "~> 3.6"},
      {:typed_struct, "~> 0.3"},
      {:uniq, "~> 0.1"}
    ]
  end

  defp description do
    """
    Generate elixir typedstructs from AVRO schemas.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: @version,
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
