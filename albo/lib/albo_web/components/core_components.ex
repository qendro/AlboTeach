defmodule AlboWeb.CoreComponents do
  use Phoenix.Component
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :options, :list, default: []

  attr :rest, :global,
    include:
      ~w(autocomplete placeholder required rows maxlength minlength checked disabled min max step list)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors =
      if Phoenix.Component.used_input?(field) ||
           match?(
             %Ecto.Changeset{action: action} when action in [:insert, :update],
             field.form.source
           ),
         do: Enum.map(field.errors, &translate_error/1),
         else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: field.value,
      errors: errors
    )
    |> input()
  end

  def input(assigns) do
    ~H"""
    <div class={if @type == "hidden", do: "hidden", else: "field"}>
      <label :if={@label} for={@id}>{@label}</label>
      <%= cond do %>
        <% @type == "textarea" -> %>
          <textarea id={@id} name={@name} aria-invalid={@errors != []} {@rest}>{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
        <% @type == "select" -> %>
          <select id={@id} name={@name} {@rest}>{Phoenix.HTML.Form.options_for_select(
            @options,
            @value
          )}</select>
        <% true -> %>
          <input
            id={@id}
            type={@type}
            name={@name}
            value={
              if @type == "checkbox",
                do: "true",
                else: Phoenix.HTML.Form.normalize_value(@type, @value)
            }
            aria-invalid={@errors != []}
            {@rest}
          />
      <% end %>
      <p :for={error <- @errors} class="field-error">{error}</p>
    </div>
    """
  end

  defp translate_error({msg, opts}),
    do:
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)

  attr :name, :string, required: true
  attr :class, :string, default: "icon"

  def icon(assigns) do
    paths = %{
      "hero-sparkles" => "M12 3l2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4L12 3Z",
      "hero-arrow-right" => "M5 12h14m-6-6 6 6-6 6",
      "hero-book-open" =>
        "M12 6c-3-3-7-3-10-2v15c3-1 7-1 10 2m0-15c3-3 7-3 10-2v15c-3-1-7-1-10 2V6Z",
      "hero-squares-2x2" => "M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7Z",
      "hero-adjustments-horizontal" =>
        "M3 6h6m4 0h8M3 12h12m4 0h2M3 18h2m4 0h12M9 3v6m6 0v6M5 15v6",
      "hero-check" => "m5 12 4 4L19 6",
      "hero-chevron-up" => "m6 15 6-6 6 6",
      "hero-chevron-down" => "m6 9 6 6 6-6",
      "hero-language" => "M3 5h12M9 3v2m4 0c-1 6-5 9-10 11m2-9c1 4 4 7 8 9m1 5 4-10 4 10m-6-3h5",
      "hero-photo" => "M3 3h18v18H3V3Zm0 14 5-5 4 4 3-3 6 6M15 7h.01",
      "hero-trash" => "M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7",
      "hero-x-mark" => "m6 6 12 12M6 18 18 6",
      "hero-arrow-path" => "M20 8a8 8 0 0 0-14-3L3 8m0-5v5h5m-4 8a8 8 0 0 0 14 3l3-3m0 5v-5h-5",
      "hero-lock-closed" => "M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5V10Zm7 4v3",
      "hero-plus" => "M12 5v14M5 12h14",
      "hero-printer" => "M6 9V3h12v6M6 18H3V9h18v9h-3M6 14h12v7H6v-7Zm11-2h1",
      "hero-arrow-down-tray" => "M12 3v12m-5-5 5 5 5-5M4 15v6h16v-6"
    }

    assigns = assign(assigns, :path, Map.fetch!(paths, assigns.name))

    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.7"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    ><path d={@path} /></svg>
    """
  end
end
