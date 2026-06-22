defmodule RuleMaven.Repo.Migrations.CreateFaqCandidates do
  use Ecto.Migration

  def change do
    create table(:faq_candidates) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :question_text, :text, null: false
      add :cluster_id, :bigint
      add :sample_answer_text, :text
      add :sample_citation, :text
      add :thumbs_down_count, :integer, default: 0
      add :total_asked_count, :integer, default: 0
      add :status, :string, null: false, default: "pending"
      add :published_faq_id, references(:faq_entries, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:faq_candidates, [:game_id])
    create index(:faq_candidates, [:status])
  end
end
