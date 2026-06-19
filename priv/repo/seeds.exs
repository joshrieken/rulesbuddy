alias RulesBuddy.Repo
alias RulesBuddy.Users.User

username = "admin"
email = "admin@rulesbuddy.local"
password = "admin"

if is_nil(Repo.get_by(User, username: username)) do
  Repo.insert!(
    User.registration_changeset(%User{}, %{
      username: username,
      email: email,
      password: password,
      role: "game_master"
    })
  )

  IO.puts("Seeded game_master user: #{username} / #{password}")
else
  IO.puts("game_master user already exists: #{username}")
end
