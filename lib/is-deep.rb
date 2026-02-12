# frozen_string_literal: true

require_relative 'is-deep/core'
require_relative 'is-deep/strategies'

class Hash
  include IS::Deep

  # Creates deep copy of hash with all nested structures.
  #
  # Handles circular references correctly. Preserves default values
  # and default_proc if present.
  #
  # @return [Hash] Deep copy of self
  # @example
  #   h = { a: { b: 1 } }
  #   copy = h.deep_dup
  #   copy[:a][:b] = 2
  #   h[:a][:b] # => 1 (unchanged)
  def deep_dup
    visited_wrap do |visited|
      self_id = self.object_id
      return visited[self_id] if visited.has_key?(self_id)
      result = {}
      visited[self_id] = result
      if self.default_proc != nil
        result.default_proc = self.default_proc
      elsif self.default != nil
        result.default = self.default
      end
      self.each do |key, value|
        id = value.object_id
        result[key] = if visited.has_key?(id)
          visited[id]
        elsif value.respond_to?(:deep_dup)
          visited[id] = value.deep_dup
        elsif value.respond_to?(:dup)
          visited[id] = value.dup
        else
          visited[id] = value
        end
      end
      result
    end
  end

  # Deep merges other hash into self, modifying receiver.
  #
  # Recursively merges nested hashes. For conflicting values where
  # old value responds to #can_merge? and returns true, attempts
  # recursive merge. Otherwise replaces with new value.
  #
  # @param other [Hash, #to_hash] Hash or hash-like object to merge
  # @param array_strategy [#call, nil] Override array merge strategy
  # @return [self] Modified receiver
  # @example
  #   h = { a: { b: 1 } }
  #   h.deep_merge!({ a: { c: 2 } })
  #   h # => { a: { b: 1, c: 2 } }
  def deep_merge! other, array_strategy: nil
    visited_wrap do |visited|
      id = self.object_id
      return self if visited.has_key?(id)
      visited[id] = self
      source = if other.is_a?(Hash)
        other
      elsif other.respond_to?(:to_hash)
        other.to_hash
      else
        raise ArgumentError, "Unsupported type of source: (#{ other.class })", caller_locations
      end
      source.each do |key, value|
        if self.has_key?(key)
          old = self[key]
          if old.respond_to?(:can_merge?) && old.can_merge?(value)
            old.deep_merge! value, array_strategy: array_strategy
          else
            self[key] = value
          end
        else
          self[key] = value
        end
      end
      self
    end
  end

  # Checks if other can be merged with this hash.
  #
  # @param other [Object] Object to check
  # @return [Boolean] True if other is hash-like
  def can_merge?(other)
    other.is_a?(Hash) || other.respond_to?(:to_hash)
  end

end

class Array
  include IS::Deep

  # Creates deep copy of array with all nested structures.
  #
  # Handles circular references correctly.
  #
  # @return [Array] Deep copy of self
  def deep_dup
    visited_wrap do |visited|
      self_id = self.object_id
      return visited[self_id] if visited.has_key?(self_id)
      result = []
      visited[self_id] = result
      self.each do |item|
        id = item.object_id
        value = if visited.has_key?(id)
            visited[id]
          elsif item.respond_to?(:deep_dup)
            visited[id] = item.deep_dup
          elsif item.respond_to?(:dup)
            visited[id] = item.dup
          else
            visited[id] = item
          end
        result << value
      end
      result
    end
  end

  # Deep merges other array into self, modifying receiver.
  #
  # Uses configured or provided array_strategy to determine
  # merge semantics. Strategy receives (base, other) and returns
  # result array.
  #
  # @param other [Array, #to_ary] Array or array-like object to merge
  # @param array_strategy [#call, nil] Override array merge strategy
  # @return [self] Modified receiver
  def deep_merge! other, array_strategy: nil
    visited_wrap do |visited|
      id = self.object_id
      return self if visited.has_key?(id)
      visited[id] = self
      source = if other.is_a?(Array)
          other
        elsif other.respond_to?(:to_ary)
          other.to_ary
        else
          raise ArgumentError, "Unsupported type of source: (#{other.class})", caller_locations
        end

      strategy = array_strategy || IS::Deep.array_strategy
      result = strategy.call(self, source)

      self.clear
      result.each { |item| self << item }

      self
    end
  end

  # Checks if other can be merged with this array.
  #
  # @param other [Object] Object to check
  # @return [Boolean] True if other is array-like
  def can_merge? other
    other.is_a?(Array) || other.respond_to?(:to_ary)
  end

end

