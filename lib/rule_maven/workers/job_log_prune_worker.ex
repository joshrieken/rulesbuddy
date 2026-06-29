defmodule RuleMaven.Workers.JobLogPruneWorker do
  @moduledoc """
  Daily maintenance for the unified job log. Prunes `job_events` (and the empty
  finished runs they belonged to) older than the 6-month retention window, and
  reconciles any `running` rows stranded by a crash/restart so the admin panel
  never shows a ghost job. Cron-scheduled; safe to run repeatedly.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias RuleMaven.Jobs

  # Keep six months of job-log history.
  @retention_days 180

  @impl Oban.Worker
  def perform(_job) do
    Jobs.reconcile_stale()
    cutoff = DateTime.add(DateTime.utc_now(), -@retention_days, :day)
    Jobs.prune_events(cutoff)
    :ok
  end
end
