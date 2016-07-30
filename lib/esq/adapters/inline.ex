defmodule Esq.Adapters.Inline do
  def push(module, args, _config) do
    apply(module, :run, args)
  end

  def push_jobs(jobs, config) do
    for {module, args} <- jobs do
      push(module, args, config)
    end
  end

  def poll(limit, config) do
    {:ok, []}
  end
end
