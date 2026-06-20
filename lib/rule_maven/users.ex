defmodule RuleMaven.Users do
  import Ecto.Query, warn: false
  alias RuleMaven.Repo
  alias RuleMaven.Users.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

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
end
