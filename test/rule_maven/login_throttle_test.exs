defmodule RuleMaven.Auth.LoginThrottleTest do
  # async: false — the throttle uses a single shared ETS table.
  use ExUnit.Case, async: false

  alias RuleMaven.Auth.LoginThrottle

  # Unique key per test so the shared table doesn't leak state between them.
  defp fresh_key(tag), do: LoginThrottle.key({127, 0, 0, 1}, "#{tag}-#{System.unique_integer()}")

  test "allows attempts under the limit, locks out after 5 failures" do
    key = fresh_key("lock")

    for _ <- 1..4 do
      assert :ok = LoginThrottle.check(key)
      LoginThrottle.record_failure(key)
    end

    # 5th failure trips the lockout.
    assert :ok = LoginThrottle.check(key)
    LoginThrottle.record_failure(key)

    assert {:error, seconds} = LoginThrottle.check(key)
    assert seconds > 0 and seconds <= 900
  end

  test "clear resets the counter" do
    key = fresh_key("clear")
    for _ <- 1..5, do: LoginThrottle.record_failure(key)
    assert {:error, _} = LoginThrottle.check(key)

    LoginThrottle.clear(key)
    assert :ok = LoginThrottle.check(key)
  end

  test "different identifiers from the same IP are tracked separately" do
    ip = {10, 0, 0, 9}
    a = LoginThrottle.key(ip, "alice-#{System.unique_integer()}")
    b = LoginThrottle.key(ip, "bob-#{System.unique_integer()}")

    for _ <- 1..5, do: LoginThrottle.record_failure(a)
    assert {:error, _} = LoginThrottle.check(a)
    assert :ok = LoginThrottle.check(b)
  end

  test "key normalizes IP tuple and downcases the identifier" do
    assert LoginThrottle.key({127, 0, 0, 1}, "ALICE") == {"127.0.0.1", "alice"}
  end
end
