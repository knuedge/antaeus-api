if CONFIG[:caching] &&
  CONFIG[:caching].has_key?(:enabled) &&
  CONFIG[:caching][:enabled]

  require 'rack/cache'

  if CONFIG[:caching].has_key?(:library)
    case CONFIG[:caching][:library].to_s
    when /[Rr]edis/
      require 'redis'
      @cache_library = :Redis
      @cache_host    = CONFIG[:caching][:host]
      @cache_port    = CONFIG[:caching][:port]
      @cache_pass    = CONFIG[:caching][:passphrase]

      fail "Missing Cache Host" unless @cache_host
      fail "Missing Cache Port" unless @cache_port
    else
      fail "Invalid Caching Library: #{CONFIG[:caching][:library].to_s}"
    end
  else
    @cache_library = :LRUHash
  end

  require 'rack/cache/moneta'

  puts ">> Caching enabled via Moneta::#{@cache_library}"
  
  cache_config = { expires: true }
  if @cache_library == :Redis
    cache_config[:host] = @cache_host
    cache_config[:port] = @cache_port
    cache_config[:password] = @cache_pass if @cache_pass
  else
    cache_config[:threadsafe] = true
    cache_config[:max_size]   = CONFIG[:caching][:size] ? CONFIG[:caching][:size] : 10240000
  end

  Rack::Cache::Moneta['antaeus'] = Moneta.new(@cache_library, cache_config)
  CACHE = Rack::Cache::Moneta['antaeus']

  use Rack::Cache,
        metastore:   'moneta://antaeus',
        entitystore: 'moneta://antaeus',
        allow_reload: true
else
  CACHE = Moneta.new(:LRUCache, threadsafe: true, max_size: 10240000)
  puts ">> Rack Cache Disabled!"
end