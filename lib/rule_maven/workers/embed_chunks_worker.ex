defmodule RuleMaven.Workers.EmbedChunksWorker do
  @moduledoc """
  Generates embeddings for all chunks of a document.
  Enqueued after document creation, runs async so uploads don't block.
  """

  use Oban.Worker, queue: :default, max_attempts: 3
  import Ecto.Query
  alias RuleMaven.Repo
  alias RuleMaven.{Games, Jobs}

  @impl Oban.Worker
  def perform(%Oban.Job{id: oban_id, args: %{"document_id" => doc_id}}) do
    # Oban serializes args to JSON: an integer enqueued as `document_id` comes
    # back an integer, a string stays a string. Accept both — passing the raw
    # integer here used to crash `String.to_integer/1` and fail every embed job.
    doc_id = normalize_id(doc_id)
    doc = Games.get_document!(doc_id)

    # Document-scoped run so the readiness pipeline (and the admin log) see embed
    # finish — `Jobs.finish_run/3` resolves the game and advances auto-prepare.
    run =
      Jobs.start_run("embed", {"document", doc.id}, "Embed chunks — #{doc.label}",
        oban_job_id: oban_id
      )

    chunks =
      Repo.all(
        from c in Games.Chunk,
          where: c.document_id == ^doc.id and is_nil(c.embedding),
          order_by: c.chunk_index
      )

    if chunks == [] do
      Jobs.finish_run(run, "done", "No chunks needed embedding.")
      :ok
    else
      texts = Enum.map(chunks, & &1.content)

      case RuleMaven.Embed.embed_batch(texts) do
        {:ok, vectors} ->
          chunks
          |> Enum.zip(vectors)
          |> Enum.each(fn {chunk, vec} ->
            Games.Chunk.changeset(chunk, %{embedding: vec})
            |> Repo.update!()
          end)

          Jobs.finish_run(run, "done", "Embedded #{length(chunks)} chunk(s).")
          :ok

        {:error, reason} ->
          Jobs.finish_run(run, "failed", "Embedding failed — #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)
end
