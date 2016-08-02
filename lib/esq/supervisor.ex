defmodule Esq.Supervisor do
  use Supervisor

  def start_link(queue, options \\ []) do
    Supervisor.start_link(__MODULE__, [queue, options], name: __MODULE__)
  end

  def init([queue, options]) do
    running = Keyword.get(options, :dispatcher, !iex?)
    pool = Keyword.get(options, :pool, Esq.WorkerPool)
    workers = Keyword.get(options, :workers, 10)

    poolboy_config = [
      {:name, {:local, pool}},
      {:worker_module, Esq.Worker},
      {:size, workers},
      {:max_overflow, 0}
    ]

    children = if running do
      [
        :poolboy.child_spec(pool, poolboy_config, []),
        worker(Esq.Dispatch, [queue, pool]),
      ]
    else
      []
    end

    supervise(children, strategy: :one_for_one)
  end

  def iex? do
    Code.ensure_loaded?(IEx) and IEx.started?
  end
end
