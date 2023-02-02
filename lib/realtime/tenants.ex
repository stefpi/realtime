defmodule Realtime.Tenants do
  @moduledoc """
  Everything to do with Tenants.
  """

  alias Realtime.Api.Tenant

  @doc """
  Gets a list of connected tenant `external_id` strings in the cluster or a node.
  """

  @spec list_connected_tenants :: [String.t()]
  def list_connected_tenants() do
    :syn.group_names(:users)
  end

  @spec list_connected_tenants(atom()) :: [String.t()]
  def list_connected_tenants(node) do
    :syn.group_names(:users, node)
  end

  @doc """
  All the keys that we use to create counters and RateLimiters for tenants.
  """

  @spec limiter_keys(Tenant.t()) :: [{atom(), atom(), String.t()}]
  def limiter_keys(%Tenant{} = tenant) do
    [
      {:plug, :requests, tenant.external_id},
      {:channel, :clients_per, tenant.external_id},
      {:channel, :joins, tenant.external_id},
      {:channel, :events, tenant.external_id}
    ]
  end

  @spec get_tenant_limits(Realtime.Api.Tenant.t(), maybe_improper_list) :: list
  def get_tenant_limits(%Tenant{} = tenant, keys) when is_list(keys) do
    nodes = [Node.self() | Node.list()]

    nodes
    |> Enum.map(fn node ->
      Task.Supervisor.async({Realtime.TaskSupervisor, node}, fn ->
        for {_key, name, _external_id} = key <- keys do
          {_status, response} = Realtime.GenCounter.get(key)

          %{
            external_id: tenant.external_id,
            node: node,
            limiter: name,
            counter: response
          }
        end
      end)
    end)
    |> Task.await_many()
    |> List.flatten()
  end
end
