defmodule MsEvaluateRules.MixProject do
  use Mix.Project

  def project do
    [
      app: :ms_evaluate_rules,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :dev,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "ca.release": :test,
        "ca.sobelow.sonar": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.xml": :test,
        credo: :test,
        release: :prod,
        sobelow: :test
      ],
      releases: [
        ms_evaluate_rules: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar]
        ]
      ],
      metrics: false
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MsEvaluateRules.Application, [Mix.env()]}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:configparser_ex, "~> 5.0"},
      {:sweet_xml, "~> 0.7"},
      {:hackney, "~> 1.25"},
      {:ex_aws_sts, "~> 2.3"},
      {:ex_aws_secretsmanager, "~> 2.0"},
      {:postgrex, "~> 0.21"},
      {:ecto_sql, "~> 3.13"},
      {:castore, "~> 1.0"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:plug_checkup, "~> 0.6"},
      {:poison, "~> 6.0"},
      {:cors_plug, "~> 3.0"},
      {:timex, "~> 3.7"},
      # Test
      {:mock, "~> 0.3", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      # Release
      {:elixir_structure_manager, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end
