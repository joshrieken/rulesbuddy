defmodule RuleMavenWeb.AdminLive.Index do
  use RuleMavenWeb, :live_view

  alias RuleMaven.{Users, Games}

  @impl true
  def mount(_params, _session, socket) do
    if Users.can?(socket.assigns.current_user, :admin) do
      {:ok,
       assign(socket,
         page_title: "Admin",
         review_backlog: Games.needs_review_count(),
         flag_backlog: Games.count_pending_flags()
       )}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="max-width:52rem;margin:0 auto;padding:1.25rem 1.5rem">
      <.link navigate={~p"/"} class="back-link">&larr; Back to games</.link>

      <h1 style="font-size:1.5rem;font-weight:700;margin:0.25rem 0 1rem">Admin Dashboard</h1>

      <.section title="Review">
        <.card
          navigate={
            if @review_backlog > 0,
              do: ~p"/admin/questions?status=needs_review",
              else: ~p"/admin/questions"
          }
          icon="💬"
          title="Questions"
          desc="Browse, filter, and delete user questions."
          badge={@review_backlog > 0 && "#{@review_backlog} to review"}
          badge_title="Community answers flagged stale by a rulebook change, awaiting re-approval"
        />
        <.card
          navigate={~p"/admin/moderation"}
          icon="🚩"
          title="Moderation"
          desc="Per-user abuse signals, vote rings, suspend/pull-answers."
          badge={@flag_backlog > 0 && "#{@flag_backlog} reported"}
          badge_title="Answers users reported as wrong or unhelpful, awaiting review"
        />
        <.card
          navigate={~p"/admin/audit"}
          icon="📜"
          title="Audit Log"
          desc="Append-only record of sensitive admin actions."
        />
        <.card
          navigate={~p"/admin/threads"}
          icon="🧵"
          title="Review Threads"
          desc="Review Q&A threads with followups. Merge into FAQ entries."
        />
      </.section>

      <.section title="Manage">
        <.card
          navigate={~p"/admin/users"}
          icon="👥"
          title="Manage Users"
          desc="Promote players to game masters. Manage roles."
        />
        <.card
          navigate={~p"/admin/invites"}
          icon="🎟️"
          title="Invite Codes"
          desc="Generate invite codes for new user registration."
        />
        <.card
          navigate={~p"/admin/catalog"}
          icon="📦"
          title="Game Catalog"
          desc="Bulk-import the full BoardGameGeek catalog (~150k games)."
        />
        <.card
          navigate={~p"/admin/requests"}
          icon="🙋"
          title="Support Requests"
          desc="Games users want supported, ranked by demand."
        />
      </.section>

      <.section title="System">
        <.card
          navigate={~p"/admin/security"}
          icon="🛡️"
          title="Security"
          desc="Blocked questions and injection pattern management."
        />
        <.card
          navigate={~p"/admin/db"}
          icon="🗄️"
          title="DB Admin"
          desc="Browse, edit, and manage database tables directly."
        />
        <.card
          navigate={~p"/admin/themes"}
          icon="🎨"
          title="Theme Usage"
          desc="Which themes users have selected."
        />
        <.card
          navigate={~p"/settings"}
          icon="🔧"
          title="Settings"
          desc="LLM provider, model, API keys, rate limits."
        />
        <.card
          href="/oban"
          target="_blank"
          icon="⚙️"
          title="Oban Dashboard ↗"
          desc="Background job queue and processing dashboard."
        />
      </.section>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :title, :string, required: true

  defp section(assigns) do
    ~H"""
    <h2 style="font-size:0.7rem;font-weight:700;text-transform:uppercase;letter-spacing:0.05em;color:var(--text-muted);margin:1.25rem 0 0.5rem">
      {@title}
    </h2>
    <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(14rem,1fr));gap:0.75rem">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :desc, :string, required: true
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :target, :string, default: nil
  attr :badge, :any, default: nil
  attr :badge_title, :string, default: nil

  defp card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      target={@target}
      style="position:relative;background:var(--bg-surface);border:1px solid var(--border);border-radius:0.5rem;padding:1.25rem;text-decoration:none;display:block"
    >
      <span
        :if={@badge}
        title={@badge_title}
        style="position:absolute;top:0.6rem;right:0.6rem;background:var(--danger,#c0392b);color:#fff;font-size:0.7rem;font-weight:700;border-radius:999px;padding:0.1rem 0.45rem"
      >
        {@badge}
      </span>
      <div style="font-size:1.5rem;margin-bottom:0.4rem">{@icon}</div>
      <div style="font-weight:700;font-size:0.9rem;color:var(--text);margin-bottom:0.2rem">
        {@title}
      </div>
      <div style="font-size:0.8rem;color:var(--text-muted)">{@desc}</div>
    </.link>
    """
  end
end
