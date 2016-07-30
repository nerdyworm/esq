defmodule EsqTest do
  use ExUnit.Case
  doctest Esq

  defmodule FakeQueue do
    use Esq.Queue, otp_app: :esq,
      adapter: Esq.Adapters.SQS,
      queue_name: "elixir",
      max_retries: 5,
      failure: Esq.Failures.Dynamodb, table_name: "FailedJobs2"
  end

  defmodule FakeJob do
    require Logger

    def run(id) do
      IO.inspect id
      :timer.sleep(1000 * 5)
      :ack
    end
  end

  test "starting" do
    for i <- 1..10 do
      FakeQueue.push(FakeJob, [i])
    end

    {:ok, pid} = Esq.Supervisor.start_link(FakeQueue)

    :timer.sleep(1000 * 10)
  end
end
