defmodule RuleMaven.Games.SupportRequest do
  use Ecto.Schema
  import Ecto.Changeset

  # A user's request that a not-yet-playable game in their collection get
  # rulebook support. Deduped per user/game.
  schema "game_support_requests" do
    belongs_to :user, RuleMaven.Users.User
    belongs_to :game, RuleMaven.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(req, attrs) do
    req
    |> cast(attrs, [:user_id, :game_id])
    |> validate_required([:user_id, :game_id])
    |> unique_constraint([:user_id, :game_id])
  end
end
