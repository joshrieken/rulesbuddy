defmodule RuleMaven.Hashid do
  @moduledoc """
  Reversible obfuscation of integer ids for use in URLs, so we never expose raw
  sequential primary keys (which leak catalog size and invite enumeration of
  unpublished rows).

  An id is mapped to an 8-char opaque token via a keyed multiplicative
  permutation over 2^40 (a bijection: `n = id * MULT mod 2^40`, inverted with the
  precomputed modular inverse) XORed with a fixed mask, then base32-encoded with a
  Crockford-style alphabet. This is obfuscation, not encryption — it stops casual
  id leakage/guessing in URLs; it is not a secret against someone with the source.

  Supports ids in `[0, 2^40)` (~1.1e12) — far above any key we mint.
  """
  import Bitwise

  @mod 1_099_511_627_776
  @mult 982_451_653
  @inv 809_470_931_213
  @mask 0xA5C39F12E7
  @len 8
  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"

  @index @alphabet |> Enum.with_index() |> Map.new()

  @doc "Encode a non-negative integer id into an 8-char opaque token."
  def encode(id) when is_integer(id) and id >= 0 and id < @mod do
    n = bxor(rem(id * @mult, @mod), @mask)
    encode_chars(n, @len - 1, [])
  end

  defp encode_chars(_n, i, acc) when i < 0, do: List.to_string(acc)

  defp encode_chars(n, i, acc) do
    char = Enum.at(@alphabet, n >>> (5 * i) &&& 31)
    encode_chars(n, i - 1, [acc | [char]])
  end

  @doc "Decode a token back to its integer id. Returns `{:ok, id}` or `:error`."
  def decode(token) when is_binary(token) do
    chars = String.to_charlist(token)

    if length(chars) == @len and Enum.all?(chars, &Map.has_key?(@index, &1)) do
      n = Enum.reduce(chars, 0, fn c, acc -> acc * 32 + Map.fetch!(@index, c) end)
      {:ok, rem(bxor(n, @mask) * @inv, @mod)}
    else
      :error
    end
  end

  def decode(_), do: :error

  @doc "Decode a token to an id, raising `Ecto.NoResultsError`-friendly on bad input."
  def decode!(token) do
    case decode(token) do
      {:ok, id} -> id
      :error -> raise ArgumentError, "invalid id token"
    end
  end
end
