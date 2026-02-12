defmodule CreditSystem.Cache do
  @moduledoc "Cache wrapper around Cachex for credit applications"

  @cache_name :credit_system_cache

  def get_application(id) do
    Cachex.get(@cache_name, {:application, id})
  end

  def put_application(id, application) do
    ttl = Application.get_env(:credit_system, :cache)[:application_ttl] || :timer.minutes(5)
    Cachex.put(@cache_name, {:application, id}, application, ttl: ttl)
  end

  def invalidate_application(id) do
    Cachex.del(@cache_name, {:application, id})
    invalidate_lists()
  end

  def get_list(key) do
    Cachex.get(@cache_name, {:list, key})
  end

  def put_list(key, data) do
    ttl = Application.get_env(:credit_system, :cache)[:list_ttl] || :timer.minutes(1)
    Cachex.put(@cache_name, {:list, key}, data, ttl: ttl)
  end

  def invalidate_lists do
    Cachex.clear(@cache_name)
  end

  def get_country_config(country) do
    Cachex.get(@cache_name, {:country_config, country})
  end

  def put_country_config(country, config) do
    ttl = Application.get_env(:credit_system, :cache)[:country_config_ttl] || :timer.hours(1)
    Cachex.put(@cache_name, {:country_config, country}, config, ttl: ttl)
  end
end
