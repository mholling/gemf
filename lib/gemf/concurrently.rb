module Concurrently
  CORES = Etc.nprocessors rescue 1

  def concurrently(threads = CORES, &block)
    elements = Queue.new
    threads.times.map do
      Thread.new do
        while element = elements.pop
          block.call element
        end
      end
    end.tap do
      inject(elements, &:<<).close
    end.each(&:join)
    self
  end
end

Enumerator.send :include, Concurrently
