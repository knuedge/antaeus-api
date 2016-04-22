module Metrics
  class << self
    def prepare
      data
    end

    def data
      @data ||= ::Concurrent::Map.new
    end

    def get(type, key)
      fail "Exceptions::MetricNotSet" unless data[type.to_sym]
      if data[type.to_sym][key.to_sym]
        data[type.to_sym][key.to_sym].value
      else
        nil
      end
    end

    def register(type)
      data.put_if_absent(type.to_sym, ::Concurrent::Map.new)
    end

    def registered?(type)
      data[type.to_sym] ? true : false
    end

    def set(type, key, value)
      fail "Exceptions::MetricNotSet" unless data[type.to_sym]
      data[type.to_sym][key.to_sym] = ::Concurrent::Atom.new(value)
    end

    def update(type, key, default = 0, &block)
      fail "Exceptions::MetricNotSet" unless data[type.to_sym]
      # This is not totally thread-safe, but should not be an issue after startup
      data[type.to_sym][key.to_sym] ||= ::Concurrent::Atom.new(default)
      data[type.to_sym][key.to_sym].swap(&block)
    end

    def to_hash
      h = {}
      data.each_pair do |t, k|
        th = {}
        k.each_pair do |key, v|
          th[key] = v.value
        end
        h[t] = th
      end
      return h
    end
  end
end
