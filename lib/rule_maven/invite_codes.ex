defmodule RuleMaven.InviteCodes do
  @moduledoc """
  Invite code management — generation, validation, consumption.
  """

  import Ecto.Query, warn: false
  alias RuleMaven.Repo
  alias RuleMaven.InviteCodes.InviteCode

  @doc """
  Generates a new invite code.
  """
  def create_code(created_by_id, opts \\ []) do
    code = generate_code()

    attrs =
      %{
        code: code,
        created_by_id: created_by_id,
        max_uses: Keyword.get(opts, :max_uses, 1),
        expires_at: Keyword.get(opts, :expires_at)
      }

    %InviteCode{}
    |> InviteCode.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Validates an invite code. Returns {:ok, code} or {:error, reason}.
  """
  def validate_code(nil), do: {:error, "Invalid invite code."}
  def validate_code(""), do: {:error, "Invalid invite code."}

  def validate_code(code) when is_binary(code) do
    case Repo.get_by(InviteCode, code: code) do
      nil ->
        {:error, "Invalid invite code."}

      %InviteCode{active: false} ->
        {:error, "This invite code is no longer active."}

      %InviteCode{expires_at: expires} = ic when not is_nil(expires) ->
        if DateTime.compare(DateTime.utc_now(), expires) == :gt do
          {:error, "This invite code has expired."}
        else
          check_remaining_uses(ic)
        end

      ic ->
        check_remaining_uses(ic)
    end
  end

  @doc """
  Consumes an invite code (increments use_count). Returns {:ok, code} or {:error, reason}.
  """
  def use_code(code) do
    case validate_code(code) do
      {:ok, ic} ->
        ic
        |> InviteCode.changeset(%{use_count: ic.use_count + 1})
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all invite codes, newest first.
  """
  def list_codes do
    Repo.all(
      from ic in InviteCode,
        order_by: [desc: ic.inserted_at],
        preload: [:created_by]
    )
  end

  @doc """
  Deactivates an invite code.
  """
  def deactivate_code(%InviteCode{} = code) do
    code
    |> InviteCode.changeset(%{active: false})
    |> Repo.update()
  end

  defp check_remaining_uses(%InviteCode{max_uses: max, use_count: count} = ic) do
    if count >= max do
      {:error, "This invite code has reached its maximum uses."}
    else
      {:ok, ic}
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(8) |> Base.encode32(padding: false)
  end
end
