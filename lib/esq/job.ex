defmodule Esq.Queue.Job do
  require Logger

  defstruct id: nil,
    module: nil, args: [], message: nil,
    tries: 0,
    errors: []

  alias Esq.Queue.Job

  def new(module, args) do
    %Job{id: UUID.uuid4, module: module, args: args}
  end

  def fail(job, why) do
    %{ job | tries: job.tries + 1, errors: [why|job.errors] }
  end

  def serialize(job) do
    job = Map.delete(job, :message)

    errors = Enum.map(job.errors, fn(error) ->
      case error do
        {why, stacktrace} ->
          %{message: why, stacktrace: from_stacktrace(stacktrace)}
        error -> error
      end
    end)

    job = Map.put(job, :errors, errors)

    Poison.encode!(job)
    |> Base.encode64
  end

  def deserialize(message) do
    data =
      Base.decode64!(message[:Body])
      |> Poison.decode!(as: %Job{})

    Map.put(data, :module, String.to_atom(data.module))
    |> Map.put(:message, message)
  end

  defp from_stacktrace(stacktrace) do
    Enum.map stacktrace, &format_line/1
  end

  defp format_line({mod, fun, args, []}) do
    format_line({mod, fun, args, [file: [], line: nil]})
  end

  defp format_line({mod, fun, _args, [file: file, line: line]}) do
    %{file: file |> convert_string, method: fun |> convert_string, number: line }
      #, context: get_context(otp_app, get_app(mod))}
  end

  defp convert_string(""), do: nil
  defp convert_string(string) when is_binary(string), do: string
  defp convert_string(obj), do: to_string(obj) |> convert_string
end
