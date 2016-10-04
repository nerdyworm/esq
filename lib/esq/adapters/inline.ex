defmodule Esq.Adapters.Inline do
  def push(module, args, _config) do
    apply(module, :run, args)
  end

  def push_jobs(jobs, config) do
    for {module, args} <- jobs do
      push(module, args, config)
    end
  end

  def poll(_limit, _config) do
    {:ok, []}
  end

  def ack(_job, _config), do: :ok
  def nack(_job, _why, _config), do: :ok
end
