# logger failure handler
#
# Logs failed jobs
#
defmodule Esq.Failures.Logger do
  require Logger

  def push(_config, job) do
    Logger.info "[FAILED] #{inspect job}"
    :ok
  end

  def failed(_config),  do: {:error, :no_impl}
  def retry!(_config),  do: {:error, :no_impl}
  def remove!(_config), do: {:error, :no_impl}
end
