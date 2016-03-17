module PooledIterator
  def self.each(iterable, pool_size, &block)
    q = Queue.new
    m = Mutex.new
    threads = []

    iterable.each do |i|
      q << Proc.new { block.call(i) }
    end

    pool_size.times do
      threads << Thread.new do
        until q.empty?
          q.pop.call
        end
      end
    end
    threads.each {|t| t.join }

    iterable
  end

  def self.collect(iterable, pool_size, collection_class = Array, &block)
    q = Queue.new
    m = Mutex.new
    threads = []
    data = collection_class.new

    iterable.each do |i|
      q << Proc.new { block.call(i) }
    end

    pool_size.times do
      threads << Thread.new do
        until q.empty?
          result = q.pop.call
          m.synchronize do
            data << result
          end
        end
      end
    end
    threads.each {|t| t.join }

    data
  end
end
