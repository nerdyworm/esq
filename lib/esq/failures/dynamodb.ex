# failure handler
#
# puts dead letters into Dynamodb do that we
# can poke and prod without having to deal
# with SQS's nuances.
defmodule Esq.Failures.Dynamodb do
  defmodule Job do
    @derive [ExAws.Dynamo.Encodable]
    defstruct [:job_id, :queue_name, :module, :payload, :t]
  end

  alias ExAws.Dynamo

  def push(config, job) do
    queue_name = Keyword.fetch!(config, :queue_name)
    table_name = Keyword.fetch!(config, :table_name)

    {:ok, _} = Dynamo.put_item(table_name, %Job{
      queue_name: queue_name,
      job_id: job.id,
      module: Atom.to_string(job.module),
      payload: Esq.Queue.Job.serialize(job),
      t: :os.system_time(:milli_seconds),
    })

    {:ok, _} = ExAws.SQS.delete_message(queue_name, job.message[:ReceiptHandle])

    :ok
  end

  def create_table!(name) do
    Dynamo.create_table(name,
     [queue_name: :hash, job_id: :range],
     [queue_name: :string, job_id: :string], 1, 1)
  end

  def failed(options) do
    queue_name = Keyword.fetch!(options, :queue_name)
    table_name = Keyword.fetch!(options, :table_name)

    {:ok, results} = ExAws.Dynamo.query(table_name,
      expression_attribute_values: [desired_queue_name: queue_name],
      key_condition_expression: "queue_name = :desired_queue_name")

    Enum.map(results["Items"], fn(result) ->
      Base.decode64!(result["payload"]["S"])
      |> Poison.decode!(as: %Esq.Queue.Job{})
    end)
  end

  def retry!(queue, job, options) do
    :ok = queue.push(String.to_atom(job.module), job.args)
    :ok = remove!(job, options)
    :ok
  end

  def remove!(job, options) do
    queue_name = Keyword.fetch!(options, :queue_name)
    table_name = Keyword.fetch!(options, :table_name)

    {:ok, _} = Dynamo.delete_item(table_name, %{
      queue_name: queue_name,
      job_id: job.id
    })

    :ok
  end
end
