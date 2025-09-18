defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.ApplicationDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.ApplicationData

  test "valid changeset with default status" do
    cs = ApplicationData.changeset(%ApplicationData{}, %{name: "app-1"})
    assert cs.valid?
    assert cs.changes.name == "app-1"
  end

  test "invalid without name" do
    cs = ApplicationData.changeset(%ApplicationData{}, %{})
    refute cs.valid?
    assert %{name: ["can't be blank"]} = errors_on(cs)
  end

  test "invalid status value" do
    cs = ApplicationData.changeset(%ApplicationData{}, %{name: "a", status: :bad})
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :status)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

