defmodule RuleMaven.Users do
  @moduledoc """
  User management — CRUD, authentication, role checks.
  """

  import Ecto.Query, warn: false
  alias RuleMaven.Repo
  alias RuleMaven.Users.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def list_users do
    Repo.all(from u in User, order_by: [desc: u.inserted_at])
  end

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user with an auto-generated temp password.
  Returns {:ok, user, password} or {:error, changeset, password}.
  Admin uses this to manually create accounts for known users.
  """
  def create_user_with_temp_password(attrs) do
    password = generate_temp_password()

    case create_user(Map.put(attrs, :password, password)) do
      {:ok, user} -> {:ok, user, password}
      {:error, changeset} -> {:error, changeset, password}
    end
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_user_role(%User{} = user, role) do
    update_user(user, %{role: role})
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def delete_user(nil), do: {:error, :not_found}

  def authenticate(username, password) do
    user = get_user_by_username(username)

    case user do
      nil ->
        {:error, "Invalid username or password"}

      user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, "Invalid username or password"}
        end
    end
  end

  def game_master?(user), do: User.game_master?(user)

  defp generate_temp_password do
    :crypto.strong_rand_bytes(10) |> Base.encode32(padding: false)
  end
end
