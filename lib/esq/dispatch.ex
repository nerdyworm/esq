defmodule Esq.Dispatch do
  require Logger
  use GenServer

  defmodule State do
    defstruct queue: nil, pool: nil
  end

  def start_link(q, pool) do
    GenServer.start_link(__MODULE__, [q, pool], name: __MODULE__)
  end

  def init([q, pool]) do
    state = %State{queue: q, pool: pool}
    Process.send_after(self, :timeout, 0)
    {:ok, state}
  end

  def handle_info(:timeout, state) do
    {updated_state, timeout} = dequeue(state)
    {:noreply, updated_state, timeout}
  end

  def handle_info({:DOWN, _, :process, _pid, :normal}, state) do
    {:noreply, state, 0}
  end

  # TODO - matches {#Reference<0.0.6.1440>, :ok}
  # Not entirely sure what this is or what to do with it
  def handle_info({_, :ok}, state) do
    {:noreply, state, 0}
  end

  defp dequeue(state) do
    case :poolboy.status(state.pool) do
      {:ready, workers, _, _} -> poll(state, workers)
      {:full, _, _, _} -> {state, 500}
    end
  end

  # TODO - configure these timeouts
  defp poll(state, workers) do
    case state.queue.poll(workers) do
      {:ok, []} -> {state, 5000}
      {:ok, jobs} ->
        dispatch(state, jobs)
        {state, 0}
      {:error, :timeout} ->
        {state, 5000}
      {:error, why} ->
        Logger.error inspect why
        {state, 5000}
    end
  end

  defp dispatch(state, jobs) when is_list(jobs) do
    Enum.each(jobs, fn(i) -> dispatch(state, i) end)
  end

  defp dispatch(state, job) do
    worker = fn(pid) ->
      Esq.Worker.run(pid, {job, state.queue})
    end

    # TODO - conigurable job timeout
    Task.async fn ->
      :poolboy.transaction(state.pool, worker, 60_0000)
    end
  end
end

