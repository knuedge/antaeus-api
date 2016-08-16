module PooledIterator
  def self.each(iterable, pool_size, &block)
    pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: 0,
      max_threads: pool_size
    )

    iterable.each do |i|
      pool.post { block.call(i) }
    end

    pool.shutdown
    pool.wait_for_termination

    iterable
  end

  def self.collect(iterable, pool_size, collection_class = Array, &block)
    pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: 0,
      max_threads: pool_size
    )
    data = Concurrent::Array.new

    iterable.each do |i|
      pool.post { data << block.call(i) }
    end

    pool.shutdown
    pool.wait_for_termination

    # Collection Class must implement #replace()
    collection_class.new.replace(data)
  end
end
