if CONFIG[:caching] &&
  CONFIG[:caching].has_key?(:enabled) &&
  CONFIG[:caching][:enabled]

  CACHE_STATUS = :enabled

  if CONFIG[:caching].has_key?(:library)
    case CONFIG[:caching][:library].to_s
    when /[Rr]edis/
      require 'redis'
      @cache_library = :Redis
      @cache_host    = CONFIG[:caching][:host]
      @cache_port    = CONFIG[:caching][:port]
      @cache_pass    = CONFIG[:caching][:passphrase]
    else
      fail "Invalid Caching Library: #{CONFIG[:caching][:library].to_s}"
    end
  else
    fail "Missing Cache Library! Try setting caching > library in the config."
  end

  puts ">> Caching #{CACHE_STATUS} via Moneta::#{@cache_library}"
  
  cache_config = { expires: true }
  if [:Redis].include? @cache_library
    fail "Missing Cache Host" unless @cache_host
    fail "Missing Cache Port" unless @cache_port
    cache_config[:host] = @cache_host
    cache_config[:port] = @cache_port
    cache_config[:password] = @cache_pass if @cache_pass
    cache_config[:threadsafe] = true
  else
    cache_config[:max_size]   = CONFIG[:caching][:size] ? CONFIG[:caching][:size] : 10240000
  end

  CACHE = Moneta.new(@cache_library, cache_config)
else
  CACHE = Moneta.new(:Null, threadsafe: true)
  CACHE_STATUS = :disabled
  puts ">> Cache #{CACHE_STATUS}!"
end

# Helper to implement "fetch or add" for the Cache
def cache_fetch(key, options = {}, &block)
  begin
    result = CACHE.load(key, options)
    if result.nil?
      if block_given?
        CACHE.store(key, block.call, options)
      else
        nil
      end
    else
      result
    end
  rescue => e
    # don't let failures poison the cache
    CACHE.clear
    nil
  end
end

# Helper to force a cache eviction / expiration
def cache_expire(key, options = {})
  CACHE.delete(key, options)
end

# Helper for backgroud cache prefetching
def ldap_prefetch(ldap_class)
  ldap_cache_expiration = begin
                            CONFIG[:caching][:expirations][:ldap]
                          rescue
                            900
                          end

  start_time = Time.now
  results = ldap_class.all
  cache_fetch("all_#{ldap_class.name.to_s.downcase}_json", expires: ldap_cache_expiration) do
    ldap_class.all.serialize(only: :id)
  end
  cache_fetch("full_all_#{ldap_class.name.to_s.downcase}_json", expires: ldap_cache_expiration) do
    ldap_class.all.serialize
  end
  end_time = Time.now
  time_taken = end_time - start_time
  puts "[LDAP Cache Worker @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Cached #{results.size} LDAP #{ldap_class} objects in #{time_taken} seconds"
end
