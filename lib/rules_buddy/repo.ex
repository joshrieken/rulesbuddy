defmodule RulesBuddy.Repo do
  use Ecto.Repo,
    otp_app: :rules_buddy,
    adapter: Ecto.Adapters.Postgres
end
