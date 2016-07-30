defmodule Esq.Adapters.SQS.Parser do
  require Record

  Record.defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlText,    Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  def messages(xml) do
    {doc, _} = xml |> :binary.bin_to_list |> :xmerl_scan.string
    event_elements = :xmerl_xpath.string('//Message', doc)

    Enum.map(event_elements, fn(event_element) ->
      parse(xmlElement(event_element, :content))
    end)
  end

  def parse(node) do
    cond do
      Record.is_record(node, :xmlElement) ->
        name    = xmlElement(node, :name)
        content = xmlElement(node, :content)
        Map.put(%{}, name, parse(content))

      Record.is_record(node, :xmlText) ->
        xmlText(node, :value) |> to_string

      is_list(node) ->
        case Enum.map(node, &(parse(&1))) do
          [text_content] when is_binary(text_content) ->
            text_content

          elements ->
            Enum.reduce(elements, %{}, fn(x, acc) ->
              if is_map(x) do
                Map.merge(acc, x)
              else
                acc
              end
            end)
        end

      true -> "Not supported to parse #{inspect node}"
    end
  end
end
