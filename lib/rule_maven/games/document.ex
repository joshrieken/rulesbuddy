defmodule RuleMaven.Games.Document do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Page do
    @moduledoc """
    A single first-class rulebook page. `index` is the 0-based physical order,
    `sheet` the physical PDF sheet number, `printed` the rulebook's printed page
    number (nil when undetected).

    Two text layers (no markers): `text` is the read-only original from
    extraction, `cleaned` the editable working copy (auto-populated by Clean Up,
    then hand-editable; nil until cleaned/edited). The effective text used
    everywhere downstream is `cleaned || text`.
    """
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :index, :integer
      field :sheet, :integer
      field :printed, :integer
      field :text, :string
      field :cleaned, :string
    end

    def changeset(page, attrs) do
      # empty_values: [] so a blank page body ("") is stored as "" rather than
      # Ecto's default of treating "" as missing and leaving the field nil.
      cast(page, attrs, [:index, :sheet, :printed, :text, :cleaned], empty_values: [])
    end
  end

  schema "documents" do
    field :label, :string
    field :full_text, :string
    field :pdf_path, :string
    field :html_path, :string
    field :source_url, :string
    field :content_type, :string
    field :file_size, :integer
    field :page_count, :integer
    field :printed_offset, :integer
    field :from_ocr, :boolean, default: false
    field :extracted_at, :utc_datetime
    field :status, :string, default: "pending_review"
    field :file_hash, :string
    # Durable cleanup progress: pages persisted so far in the active run (nil
    # when idle). Updated incrementally by CleanupWorker so the UI counter is
    # reliable and survives refreshes.
    field :cleaning_done, :integer
    embeds_many :pages, Page, on_replace: :delete
    has_many :cheatsheet_versions, RuleMaven.CheatSheet.CheatSheetVersion
    belongs_to :game, RuleMaven.Games.Game
    belongs_to :reviewed_by, RuleMaven.Users.User

    field :reviewed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :label,
      :full_text,
      :game_id,
      :pdf_path,
      :html_path,
      :source_url,
      :content_type,
      :file_size,
      :page_count,
      :printed_offset,
      :from_ocr,
      :extracted_at,
      :status,
      :file_hash,
      :reviewed_by_id,
      :reviewed_at
    ])
    |> cast_embed(:pages, with: &Page.changeset/2)
    |> validate_required([:label, :full_text, :game_id])
  end
end
