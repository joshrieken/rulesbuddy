defmodule RuleMaven.Jobs.JobRun do
  @moduledoc """
  One background job run in the unified admin job log. A run is the lifecycle
  envelope (kind, scope, state, timing) for a single execution of a worker;
  individual progress lines hang off it as `JobEvent`s. Durable (Postgres) so the
  whole log survives a browser refresh and an Oban/server restart — the admin
  DevTools-style panel rebuilds purely from these rows.
  """
  use Ecto.Schema

  alias RuleMaven.Jobs.JobEvent

  @states ~w(running done failed)

  schema "job_runs" do
    field :kind, :string
    field :scope_type, :string, default: "global"
    field :scope_id, :integer
    field :label, :string
    field :state, :string, default: "running"
    field :summary, :string
    field :oban_job_id, :integer
    # Per-run LLM/embedding spend in USD, stamped at finish from this run's
    # `llm_logs` window (see `RuleMaven.Jobs.finish_run/3`). nil for non-LLM runs.
    field :cost_usd, :float
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec

    has_many :events, JobEvent, preload_order: [asc: :id]

    timestamps()
  end

  def states, do: @states
end
