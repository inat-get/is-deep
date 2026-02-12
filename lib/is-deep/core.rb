# frozen_string_literal: true

module IS; end

# Deep merge functionality for Ruby collections.
#
# This module provides deep merge, deep duplication, and configurable
# array merge strategies for Hash and Array classes.
#
# @example Basic usage
#   { a: 1 }.deep_merge({ b: 2 }) # => { a: 1, b: 2 }
#   { x: [1] }.deep_merge({ x: [2] }) # => { x: [1, 2] } (with concat strategy)
#
# @example Custom array strategy
#   IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE
#   { x: [1] }.deep_merge({ x: [2] }) # => { x: [2] }
#
module IS::Deep

  class << self

    # @!attribute [rw] array_strategy
    # The current array merge strategy.
    #
    # The strategy is thread-local. If not set for current thread,
    # falls back to global default.
    #
    # @return [#call] Callable object accepting (base, other) arguments
    # @see ArrayStrategies
    def array_strategy
      Thread.current[:is_deep_array_strategy] || @default_array_strategy
    end

    def array_strategy= strategy
      @default_array_strategy ||= strategy
      Thread.current[:is_deep_array_strategy] = strategy
    end

  end

  # Стратегия по умолчанию — concat
  self.array_strategy = lambda { |base, other| base + other }

  # Performs deep merge on a duplicate of the receiver.
  #
  # Creates a deep copy of self, then merges other into it.
  # Non-destructive operation — original receiver is not modified.
  #
  # @param other [Object] Object to merge into self
  # @param array_strategy [#call, nil] Optional override for array merge strategy
  # @return [IS::Deep] New object containing merged data
  # @example
  #   base = { a: { b: 1 } }
  #   base.deep_merge({ a: { c: 2 } }) # => { a: { b: 1, c: 2 } }
  #   base # => { a: { b: 1 } } (unchanged)
  def deep_merge other, array_strategy: nil
    base = if self.respond_to?(:deep_dup)
        self.deep_dup
      elsif self.respond_to?(:dup)
        self.dup
      else
        self
      end
    if base.respond_to?(:deep_merge!)
      base.deep_merge! other, array_strategy: array_strategy
    elsif base.respond_to?(:merge)
      base.merge other
    elsif base.respond_to?(:merge!)
      base.merge! other
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
