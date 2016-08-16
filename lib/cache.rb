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
      # Debug Logging
      puts "[Cache Fetch @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
        "Cache Miss for #{key}" if debugging?

      metric_key = 'cache.miss'
      if Metrics.registered?(:counts)
        Metrics.update(:counts, metric_key) {|c| c + 1 }
      end

      if block_given?
        block_result = block.call
        CACHE.store(key, block_result, options)
        metric_key = 'cache.store'
        if Metrics.registered?(:counts)
          Metrics.update(:counts, metric_key) {|c| c + 1 }
        end
        puts "[Cache Store @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
          "Cached #{key}" if debugging?
        block_result
      else
        nil
      end
    else
      puts "[Cache Fetch @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
        "Cache Hit for #{key}" if debugging?

      metric_key = 'cache.hit'
      if Metrics.registered?(:counts)
        Metrics.update(:counts, metric_key) {|c| c + 1 }
      end
      result
    end
  rescue => e
    puts "[Cache Fetch @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Failed to fetch #{key} from cache: #{e.message}" if debugging?
    # don't let failures poison the cache
    begin
      cache_expire(key)
    rescue => e
      # ignore failures to expire non-existent cache keys
    end
    nil
  end
end

# Helper to force a cache eviction / expiration
def cache_expire(key, options = {})
  CACHE.delete(key, options)
  puts "[Cache Expire @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Cache Expired for #{key}" if debugging?
end

# Helper for backgroud cache prefetching
def ldap_prefetch(ldap_class, additional_attrs = [])
  ldap_cache_expiration = begin
                            CONFIG[:caching][:expirations][:ldap]
                          rescue
                            900
                          end

  start_time = Time.now
  results = ldap_class.all
  puts "[LDAP Cache Worker @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Fetching lazy JSON for #{ldap_class.name.to_s}..." if debugging?
  cache_fetch("all_#{ldap_class.name.to_s.downcase}_json", expires: ldap_cache_expiration) do
    ldap_class.all.serialize(only: :id)
  end
  puts "[LDAP Cache Worker @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Fetching full JSON for #{ldap_class.name.to_s}..." if debugging?
  cache_fetch("full_all_#{ldap_class.name.to_s.downcase}_json", expires: ldap_cache_expiration) do
    ldap_class.all.serialize(include: additional_attrs)
  end
  end_time = Time.now
  time_taken = end_time - start_time
  puts "[LDAP Cache Worker @ #{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}]: " +
    "Cached #{results.size} LDAP #{ldap_class} objects in #{time_taken} seconds" if debugging?
end
