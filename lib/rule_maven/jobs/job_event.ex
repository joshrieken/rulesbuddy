defmodule RuleMaven.Jobs.JobEvent do
  @moduledoc """
  One progress line of a `JobRun`. Append-only (one INSERT per event) so the
  concurrent fan-out inside a worker can write without a read-modify-write race,
  and durable so the line survives a refresh/restart. `level` drives the line
  colour in the panel (shared vocabulary with the old ingest/reextract logs).
  """
  use Ecto.Schema

  alias RuleMaven.Jobs.JobRun

  schema "job_events" do
    field :level, :string, default: "info"
    field :message, :string
    field :meta, :map, default: %{}

    belongs_to :job_run, JobRun

    timestamps(updated_at: false)
  end
end
