defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository do
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.Accumulator

  def get_accumulator_definition(acc_name) do
    case Repo.get_by(Accumulator, name: acc_name, status: :active) do
      %Accumulator{} = defn -> {:ok, defn}
      _ -> {:error, :not_found}
    end
  end
end
