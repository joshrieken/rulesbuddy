alias RuleMaven.Repo
alias RuleMaven.Users.User

# --- Admin User ---

username = "admin"
email = "admin@rulemaven.local"
password = "admin"

if is_nil(Repo.get_by(User, username: username)) do
  Repo.insert!(
    User.registration_changeset(%User{}, %{
      username: username,
      email: email,
      password: password,
      role: "admin"
    })
  )

  IO.puts("Seeded admin user: #{username} / #{password}")
else
  IO.puts("admin user already exists: #{username}")
end

# --- Regular User ---

user_username = "user"
user_email = "user@rulemaven.local"
user_password = "user"

if is_nil(Repo.get_by(User, username: user_username)) do
  Repo.insert!(
    User.registration_changeset(%User{}, %{
      username: user_username,
      email: user_email,
      password: user_password,
      role: "user"
    })
  )

  IO.puts("Seeded regular user: #{user_username} / #{user_password}")
else
  IO.puts("regular user already exists: #{user_username}")
end

IO.puts(
  "\nSeeds complete! Log in at http://localhost:4000/login with admin / admin or player / player"
)

IO.puts("Use BGG import to add your games.")
