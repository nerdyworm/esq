defmodule Esq.Supervisor do
  use Supervisor

  def start_link(queue, options \\ []) do
    Supervisor.start_link(__MODULE__, [queue, options], name: __MODULE__)
  end

  def init([queue, options]) do
    pool = Keyword.get(options, :pool, Esq.WorkerPool)
    workers = Keyword.get(options, :workers, 10)

    poolboy_config = [
      {:name, {:local, pool}},
      {:worker_module, Esq.Worker},
      {:size, workers},
      {:max_overflow, 0}
    ]

    children = [
      :poolboy.child_spec(pool, poolboy_config, []),
      worker(Esq.Dispatch, [queue, pool]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
