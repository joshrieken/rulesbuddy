defmodule RuleMaven.BggRefresher do
  @moduledoc """
  Background process for BGG refresh. Survives LiveView reconnects.
  Registered as :bgg_refresher. Subscribers receive progress/complete messages.
  """
  use GenServer

  @name :bgg_refresher

  # Client API

  def running?, do: Process.whereis(@name) != nil

  def state do
    case Process.whereis(@name) do
      nil -> nil
      pid -> GenServer.call(pid, :state)
    end
  end

  def start(games) do
    case Process.whereis(@name) do
      nil -> GenServer.start(__MODULE__, games, name: @name)
      _ -> {:error, :already_running}
    end
  end

  def restart(games) do
    case Process.whereis(@name) do
      nil ->
        GenServer.start(__MODULE__, games, name: @name)

      pid ->
        GenServer.stop(pid)
        GenServer.start(__MODULE__, games, name: @name)
    end
  end

  def subscribe(pid) do
    case Process.whereis(@name) do
      nil -> :not_running
      server -> GenServer.cast(server, {:subscribe, pid})
    end
  end

  def progress(name, current, total) do
    GenServer.cast(@name, {:progress, name, current, total})
  end

  def done(name, status) do
    GenServer.cast(@name, {:done, name, status})
  end

  def complete do
    GenServer.cast(@name, :complete)
  end

  # GenServer callbacks

  @impl true
  def init(games) do
    state = %{
      total: length(games),
      current: 0,
      log: [],
      complete: false,
      errored: false,
      error_count: 0,
      subscribers: []
    }

    {:ok, task} = Task.start(fn -> run_refresh(games) end)
    Process.monitor(task)

    {:ok, Map.put(state, :task_pid, task)}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, Map.drop(state, [:subscribers, :task_pid]), state}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    {:noreply, %{state | subscribers: [pid | state.subscribers]}}
  end

  def handle_cast({:progress, name, current, total}, state) do
    log = ["#{current}/#{total}: #{name}..." | state.log]
    broadcast(state.subscribers, {:progress, name, current, total})
    {:noreply, %{state | current: current, log: log}}
  end

  def handle_cast({:done, name, status}, state) do
    icon = if status == :ok, do: "✓", else: "✗"
    log = ["  #{icon} #{name}" | state.log]
    err = if status == :error, do: state.error_count + 1, else: state.error_count
    broadcast(state.subscribers, {:done, name, status})
    {:noreply, %{state | log: log, error_count: err}}
  end

  def handle_cast(:complete, state) do
    broadcast(state.subscribers, {:complete})
    {:noreply, %{state | complete: true}}
  end

  def handle_cast({:error, reason}, state) do
    log = ["  ✗ ERROR: #{reason}" | state.log]
    broadcast(state.subscribers, {:refresh_error, reason})
    {:noreply, %{state | log: log, errored: true}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    unless state.complete do
      log = ["  ✗ Refresh task died unexpectedly" | state.log]
      broadcast(state.subscribers, {:refresh_error, "task died"})
      {:noreply, %{state | log: log, errored: true}}
    else
      {:noreply, state}
    end
  end

  defp run_refresh(games) do
    total = length(games)

    try do
      games
      |> Enum.with_index(1)
      |> Task.async_stream(
        fn {game, i} ->
          __MODULE__.progress(game.name, i, total)
          :timer.sleep(2000)

          case RuleMaven.BGG.enrich_game(game, force: true) do
            {:ok, _} -> __MODULE__.done(game.name, :ok)
            {:error, _} -> __MODULE__.done(game.name, :error)
          end
        end,
        max_concurrency: 2,
        ordered: false,
        timeout: 120_000,
        on_timeout: :kill_task
      )
      |> Stream.run()

      __MODULE__.complete()
    rescue
      e ->
        require Logger
        Logger.error("BGG refresh task crashed: #{inspect(e)}")
        GenServer.cast(@name, {:error, Exception.message(e)})
    end
  end

  defp broadcast(subscribers, msg) do
    Enum.each(subscribers, &send(&1, msg))
  end
end
