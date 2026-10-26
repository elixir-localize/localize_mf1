defmodule Localize.Message.MF1.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :localize_mf1,
      version: @version,
      elixir: "~> 1.17",
      name: "Localize MF1",
      description: description(),
      source_url: "https://github.com/elixir-localize/localize_mf1",
      package: package(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_add_apps: ~w(gettext ex_money)a,
        flags: [
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  defp description do
    """
    ICU MessageFormat 1 (plural, select, selectordinal and formatted arguments)
    for the Localize library, with Gettext interpolation.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: links(),
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/elixir-localize/localize_mf1",
      "Readme" => "https://github.com/elixir-localize/localize_mf1/blob/v#{@version}/README.md",
      "Changelog" =>
        "https://github.com/elixir-localize/localize_mf1/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp docs do
    [
      main: "readme",
      formatters: ["html", "markdown"],
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: []
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:localize, "~> 1.4"},
      {:nimble_parsec, "~> 1.0"},
      {:gettext, "~> 1.0", optional: true},
      {:ex_money, "~> 6.0", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :release], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  # Ensure CLDR locale data for the locales referenced in tests is present
  # before the suite runs. The download is a no-op when the cache is
  # already populated.
  defp aliases do
    [
      test: ["localize.download_locales", "test"]
    ]
  end
end
