defmodule Esq.Adapters.SQS do
  require Logger

  @backoff [1, 2, 4, 8, 16]

  alias Esq.Adapters.SQS.Parser

  def poll(limit, config) do
    queue_name = Keyword.get(config, :queue_name, "elixir")
    wait_time_seconds = Keyword.get(config, :wait_time_seconds, 20)

    limit = if limit > 10 do
      10
    else
      limit
    end

    Logger.debug "[SQS] polling queue=#{queue_name} limit=#{limit}"

    {:ok, response} = ExAws.SQS.receive_message(queue_name, [
      wait_time_seconds: wait_time_seconds,
      max_number_of_messages: limit
    ])

    # TODO - this can raise deserialization errors
    jobs =
      Parser.messages(response.body)
      |> Enum.map(&Esq.Queue.Job.deserialize/1)

    Logger.debug "[SQS] polling result=#{length(jobs)}"

    {:ok, jobs}
  end

  def ack(job, config) do
    queue_name = Keyword.fetch!(config, :queue_name)
    case ExAws.SQS.delete_message(queue_name, job.message[:ReceiptHandle]) do
      {:ok, _} -> :ok
    end
  end

  def push(module, args, config) do
    queue_name = Keyword.fetch!(config, :queue_name)
    job = Esq.Queue.Job.new(module, args)
    payload = Esq.Queue.Job.serialize(job)
    case ExAws.SQS.send_message(queue_name, payload) do
      {:ok, _} -> :ok
    end
  end

  def push_jobs(jobs, config) do
    payload = Enum.map(jobs, fn({module, args}) ->
      job = Esq.Queue.Job.new(module, args)
      body = job |> Esq.Queue.Job.serialize

      [id: job.id, message_body: body]
    end)

    queue_name = Keyword.fetch!(config, :queue_name)
    case ExAws.SQS.send_message_batch(queue_name, payload) do
      {:ok, _} -> :ok
    end
  end

  def nack(job, why, options \\ []) do
    max_retries = Keyword.get(options, :max_retries, 5)

    job = Esq.Queue.Job.fail(job, why)
    if job.tries < max_retries do
      retry(job, options)
    else
      fail!(options, job)
    end
  end

  defp retry(job, config) do
    queue_name = Keyword.fetch!(config, :queue_name)
    payload = Esq.Queue.Job.serialize(job)

    delay = Enum.at(@backoff, job.tries) |> jitter

    {:ok, _} = ExAws.SQS.send_message(queue_name, payload, [delay_seconds: delay])
    {:ok, _} = ExAws.SQS.delete_message(queue_name, job.message[:ReceiptHandle])
  end

  defp fail!(config, job) do
    failure = Keyword.fetch!(config, :failure)
    :ok = apply(failure, :push, [config, job])
  end

  defp jitter(seconds) when is_nil(seconds), do: jitter(1)
  defp jitter(seconds) do
    seconds + :random.uniform(seconds)
  end
end
