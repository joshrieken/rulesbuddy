defmodule RuleMaven.LLM.Savings do
  @moduledoc """
  Append-only ledger of estimated/real LLM cost savings.

  Three kinds:
    * "cache_hit"    — a pool hit avoided a whole LLM ask. Real avoidance, the
                       amount is estimated from recent real usage.
    * "prompt_cache" — provider billed cached input tokens at a lower rate. Real
                       discount.
    * "cheap_route"  — an op ran on a cheap model instead of the answer model.
                       Counterfactual; never summed into the headline total.

  Writes are best-effort: a ledger failure must never break the request path.
  """
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias RuleMaven.Repo

  @kinds ~w(cache_hit prompt_cache cheap_route)

  schema "llm_savings" do
    field :kind, :string
    field :operation, :string
    field :estimated_tokens, :integer, default: 0
    field :estimated_usd, :float, default: 0.0
    field :model, :string
    field :game_id, :id
    field :user_id, :id

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc "Best-effort insert of a savings row. Always returns :ok."
  def record(kind, attrs) when kind in @kinds do
    attrs = Map.put(attrs, :kind, kind)

    %__MODULE__{}
    |> cast(attrs, [:kind, :operation, :estimated_tokens, :estimated_usd, :model, :game_id, :user_id])
    |> validate_required([:kind])
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, cs} -> Logger.warning("Savings.record failed: #{inspect(cs.errors)}"); :ok
    end
  rescue
    e -> Logger.warning("Savings.record raised: #{inspect(e)}"); :ok
  end

  def record(_kind, _attrs), do: :ok
end
