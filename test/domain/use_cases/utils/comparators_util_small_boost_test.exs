defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtilSmallBoostTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.ComparatorsUtil, as: CU

  test "missing/exists combos and unknown ops" do
    assert CU.compare(:__missing__, "missing", :anything, "number") == true
    assert CU.compare(:__missing__, "exists", :anything, "number") == false
    assert CU.compare(1, "unknown", 1, "number") == false
    # uuid unknown
    u = Ecto.UUID.generate()
    assert CU.compare(u, "unknown", u, "uuid") == false
  end
end

