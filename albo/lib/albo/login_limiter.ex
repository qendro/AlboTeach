defmodule Albo.LoginLimiter do
  use GenServer

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, %{}, Keyword.put(opts, :name, __MODULE__))

  def allow?(ip), do: GenServer.call(__MODULE__, {:attempt, ip})
  @impl true
  def init(state), do: {:ok, state}
  @impl true
  def handle_call({:attempt, ip}, _from, state) do
    now = System.monotonic_time(:second)
    state = Map.reject(state, fn {_, {start, _}} -> now - start >= 60 end)
    {start, count} = Map.get(state, ip, {now, 0})
    allowed = count < 10 && (map_size(state) < 10_000 || Map.has_key?(state, ip))
    state = if allowed, do: Map.put(state, ip, {start, count + 1}), else: state
    {:reply, allowed, state}
  end
end
