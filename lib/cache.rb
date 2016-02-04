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
    cache_config[:threadsafe] = true
  else
    cache_config[:max_size]   = CONFIG[:caching][:size] ? CONFIG[:caching][:size] : 10240000
  end

  CACHE = Moneta.new(@cache_library, cache_config)
else
  CACHE = Moneta.new(:Null, threadsafe: true)
  puts ">> Cache Disabled!"
end

# Helper to implement "fetch or add" for the Cache
def cache_fetch(key, options = {}, &block)
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
end
