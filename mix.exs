defmodule VL6180X.MixProject do
  use Mix.Project

  def project do
    [
      app: :vl6180x,
      version: "0.1.0",
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Nerves_VL6180X",
      source_url: "https://github.com/OleMchls/nerves_vl6180x"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_i2c, "~> 0.1"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "AboutElixir library to interface with the VL6180X Time-of-Flight sensor"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "vl6180x",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/OleMchls/nerves_vl6180x"}
    ]
  end
end