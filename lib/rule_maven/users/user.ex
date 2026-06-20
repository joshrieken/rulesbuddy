defmodule RuleMaven.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :role, :string, default: "player"
    field :password, :string, virtual: true
    field :password_hash, :string

    timestamps(type: :utc_datetime)
  end

  @admin_roles ["game_master"]
  @all_roles ["player", "game_master"]

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :role])
    |> validate_required([:username, :email, :role])
    |> validate_inclusion(:role, @all_roles)
    |> validate_length(:username, max: 80)
    |> validate_length(:email, max: 160)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 4, max: 128)
    |> put_password_hash()
  end

  def game_master?(%{role: role}), do: role in @admin_roles
  def game_master?(_), do: false

  defp put_password_hash(changeset) do
    case changeset do
      %{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pass))

      _ ->
        changeset
    end
  end
end
