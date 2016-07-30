defmodule Esq.Worker do
  require Logger

  use GenServer

  def start_link([]) do
    :gen_server.start_link(__MODULE__, [], [])
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({job, queue}, _from, state) do
    log_info(job, "args=#{Poison.encode!(job.args)}")

    {time, res} = :timer.tc fn ->
      try do
        apply(job.module, :run, job.args)
      rescue
        error ->
          {:error, format_error(error)}
      end
    end

    case res do
      :ack ->
        queue.ack(job)
        log_info(job, "runtime=#{time / 1000}ms")

      {:error, message} ->
        log_error(job, message)
        queue.nack(job, message)
    end

    {:reply, :ok, state}
  end

  def run(pid, value, timeout \\ 60_000) do
    GenServer.call(pid, value, timeout)
  end

  defp log_info(job, message), do: Logger.info "#{prefix(job)} #{message}"
  defp log_error(job, message), do: Logger.error "#{prefix(job)} #{message}"
  defp prefix(job) do
    prefix = "[#{job.id}] [#{job.module}]"

    if job.tries > 0 do
      prefix <> " [tries:#{job.tries}]"
    else
      prefix
    end

  end

  defp format_error(error), do: "#{Exception.message(error)}\n#{Exception.format_stacktrace(:erlang.get_stacktrace())}"
end
