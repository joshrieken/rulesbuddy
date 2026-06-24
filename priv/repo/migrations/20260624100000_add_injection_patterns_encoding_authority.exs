defmodule RuleMaven.Repo.Migrations.AddInjectionPatternsEncodingAuthority do
  use Ecto.Migration

  def change do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    patterns = [
      # encoding / format manipulation
      {"base64", "encoding"},
      {"answer in base64", "encoding"},
      {"respond in base64", "encoding"},
      {"encode your response", "encoding"},
      {"encode your answer", "encoding"},
      {"output in base64", "encoding"},
      {"base64 encoded", "encoding"},
      {"in hex format", "encoding"},
      {"hex encoded", "encoding"},
      {"respond in hex", "encoding"},
      {"answer in hex", "encoding"},
      {"in binary format", "encoding"},
      {"morse code", "encoding"},
      {"rot13", "encoding"},
      {"caesar cipher", "encoding"},
      {"pig latin", "encoding"},
      {"respond only with code", "encoding"},
      {"output as json", "encoding"},
      {"respond in json", "encoding"},
      {"format your response as", "encoding"},
      {"respond only in", "encoding"},
      {"answer only in", "encoding"},
      {"translate your response", "encoding"},
      {"translate your answer", "encoding"},

      # authority / social engineering
      {"court ordered", "authority_social"},
      {"by court order", "authority_social"},
      {"legally required", "authority_social"},
      {"required by law", "authority_social"},
      {"for legal reasons", "authority_social"},
      {"my lawyer", "authority_social"},
      {"legally mandated", "authority_social"},
      {"it is illegal", "authority_social"},
      {"it's illegal", "authority_social"},
      {"law requires", "authority_social"},
      {"the law says", "authority_social"},
      {"law enforcement", "authority_social"},
      {"police require", "authority_social"},
      {"government requires", "authority_social"},
      {"authorized by", "authority_social"},
      {"i am your developer", "authority_social"},
      {"i am an anthropic", "authority_social"},
      {"this is a test", "authority_social"},
      {"maintenance mode", "authority_social"},
      {"debug mode", "authority_social"},
      {"diagnostic mode", "authority_social"},

      # fictional / hypothetical framing
      {"in a story where you", "fictional_framing"},
      {"hypothetically if you", "fictional_framing"},
      {"for a movie script", "fictional_framing"},
      {"write a story where you", "fictional_framing"},
      {"in a fictional world where you", "fictional_framing"},
      {"imagine a world where", "fictional_framing"},
      {"let's play a game where you", "fictional_framing"},
      {"for creative writing purposes", "fictional_framing"},

      # output manipulation
      {"ignore the format", "output_manipulation"},
      {"disregard the format", "output_manipulation"},
      {"don't use the format", "output_manipulation"},
      {"skip the citation", "output_manipulation"},
      {"no citation needed", "output_manipulation"},
      {"without the citation", "output_manipulation"},
      {"ignore your output format", "output_manipulation"},
    ]

    rows =
      patterns
      |> Enum.reject(fn {pattern, _} ->
        # Skip if already exists (idempotent)
        RuleMaven.Repo.get_by(RuleMaven.Security.InjectionPattern, pattern: pattern) != nil
      end)
      |> Enum.map(fn {pattern, category} ->
        %{pattern: pattern, category: category, enabled: true, note: nil,
          inserted_at: now, updated_at: now}
      end)

    if rows != [] do
      execute(fn -> repo().insert_all("injection_patterns", rows, on_conflict: :nothing) end, fn -> :ok end)
    end
  end
end
