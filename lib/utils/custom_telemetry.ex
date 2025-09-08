defmodule MsEvaluateRules.Utils.CustomTelemetry do
  @moduledoc false

  # Ejecuta un evento de Telemetry con métrica y valor (con metadata opcional)
  def execute_custom_event(metric, value, metadata \\ %{}) do
    metric_list = List.wrap(metric)
    event = [:elixir | metric_list]
    :telemetry.execute(event, %{duration: value}, add_service(metadata))
  end

  # Maneja un evento de Telemetry con medidas y metadata
  def handle_custom_event(metric, measures, metadata, _config) do
    event = [:elixir | List.wrap(metric)]
    :telemetry.execute(event, measures, add_service(metadata))
  end

  defp add_service(metadata) when is_map(metadata) do
    Map.put_new(metadata, :service, service_name())
  end

  defp service_name do
    # Prioriza configuración explícita si está presente
    Application.get_env(:ms_evaluate_rules, :service_name) ||
      Application.get_env(:test, :service_name) ||
      Application.get_env(:ms_evaluate_rules, :custom_metrics_prefix_name, "ms_evaluate_rules")
  end
end

