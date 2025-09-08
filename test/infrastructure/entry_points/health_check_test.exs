defmodule MsEvaluateRules.Infrastructure.EntryPoints.HealthCheckTest do
  alias MsEvaluateRules.Infrastructure.EntryPoint.HealthCheck

  use ExUnit.Case

  describe "check_http/0" do
    test "returns :ok" do
      assert HealthCheck.check_http() == :ok
    end
  end

  test "checks/0 returns http check definition" do
    [check] = HealthCheck.checks()
    assert check.name == "http"
    assert check.module == HealthCheck
    assert check.function == :check_http
  end
end
