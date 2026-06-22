defmodule RuleMaven.InviteCodes.InviteCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invite_codes" do
    field :code, :string
    field :max_uses, :integer, default: 1
    field :use_count, :integer, default: 0
    field :active, :boolean, default: true
    field :expires_at, :utc_datetime
    belongs_to :created_by, RuleMaven.Users.User

    timestamps(type: :utc_datetime)
  end

  def changeset(invite_code, attrs) do
    invite_code
    |> cast(attrs, [:code, :max_uses, :use_count, :active, :expires_at, :created_by_id])
    |> validate_required([:code, :created_by_id])
    |> unique_constraint(:code)
    |> validate_number(:max_uses, greater_than: 0)
    |> validate_number(:use_count, greater_than_or_equal_to: 0)
  end
end
