defmodule Esq.Queue do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {otp_app, adapter, failure, config} = Esq.Queue.parse_config(__MODULE__, opts)

      @adapter adapter
      @failure failure
      @config  config

      def __adapter__, do: @adapter
      def __failure__, do: @failure

      def start_link(opts \\ []) do
        Esq.Supervisor.start_link(__MODULE__, opts)
      end

      def stop(pid, timeout \\ 5000) do
        Supervisor.stop(pid, :normal, timeout)
      end

      def push(module, args, options \\ []) when is_atom(module) do
        config = Keyword.merge(@config, options)
        @adapter.push(module, args, config)
      end

      def push_jobs(jobs, options \\ []) do
        config = Keyword.merge(@config, options)
        @adapter.push_jobs(jobs, config)
      end

      def poll(limit \\ 10, options \\ []) do
        options = Keyword.merge(@config, options)
        @adapter.poll(limit, options)
      end

      def ack(job, options \\ []) do
        options = Keyword.merge(@config, options)
        @adapter.ack(job, options)
      end

      def nack(job, why, options \\ []) do
        options = Keyword.merge(@config, options)
        @adapter.nack(job, why, options)
      end

      def failed do
        @failure.failed(@config)
      end

      # Retries a job that is on the failure queue
      def retry!(job) do
        @failure.retry!(__MODULE__, job, @config)
      end

      # Removes a job from the failure queue
      def remove!(job) do
        @failure.remove!(job, @config)
      end
    end
  end

  @doc """
  Parses the OTP configuration at compile time.
  """
  def parse_config(queue, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, queue, [])
    config = Keyword.merge(config, opts)
    adapter = opts[:adapter] || config[:adapter]
    failure = config[:failure]

    unless adapter do
      raise ArgumentError, "missing :adapter configuration in " <>
      "config #{inspect otp_app}, #{inspect queue}"
    end

    {otp_app, adapter, failure, config}
  end
end

