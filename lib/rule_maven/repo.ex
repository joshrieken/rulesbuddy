defmodule RuleMaven.Repo do
  use Ecto.Repo,
    otp_app: :rule_maven,
    adapter: Ecto.Adapters.Postgres
end
