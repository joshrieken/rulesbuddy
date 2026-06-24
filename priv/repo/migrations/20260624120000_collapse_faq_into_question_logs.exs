defmodule RuleMaven.Repo.Migrations.CollapseFaqIntoQuestionLogs do
  use Ecto.Migration

  def up do
    alter table(:questions_log) do
      add :canonical_question, :text
      add :canonical_answer, :text
    end

    drop_if_exists table(:faq_candidates)
    drop_if_exists table(:faq_entries)
  end

  def down do
    alter table(:questions_log) do
      remove :canonical_question
      remove :canonical_answer
    end
  end
end
