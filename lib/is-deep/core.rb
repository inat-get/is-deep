# frozen_string_literal: true

module IS; end

module IS::Deep

  class << self

    def array_strategy
      Thread.current[:is_deep_array_strategy] || @default_array_strategy
    end

    def array_strategy=(strategy)
      @default_array_strategy ||= strategy
      Thread.current[:is_deep_array_strategy] = strategy
    end
    
  end

  # Стратегия по умолчанию — concat
  self.array_strategy = lambda { |base, other| base + other }

  # @return [IS::Deep]
  def deep_merge(other, array_strategy: nil)
    base = if self.respond_to?(:deep_dup)
        self.deep_dup
      elsif self.respond_to?(:dup)
        self.dup
      else
        self
      end
    if base.respond_to?(:deep_merge!)
      base.deep_merge!(other, array_strategy: array_strategy)
    elsif base.respond_to?(:merge)
      base.merge(other)
    elsif base.respond_to?(:merge!)
      base.merge!(other)
    else
      raise NoMethodError, "No merge methods in receiver (#{base.class})", caller_locations
    end
  end

  private

  def visited_data
    Thread::current[:deep_merge_visited_data] ||= { data: {}, level: 0 }
  end

  def reset_visited_data!
    Thread::current[:deep_merge_visited_data] = nil
  end

  protected

  # @private
  def visited_wrap
    raise ArgumentError, "Block is required", caller_locations unless block_given?
    data = visited_data
    data[:level] += 1
    yield data[:data]
  ensure
    data[:level] -= 1
    if data[:level] == 0
      reset_visited_data!
    end
  end

end
