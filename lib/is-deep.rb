# frozen_string_literal: true

require_relative 'is-deep/core'
require_relative 'is-deep/strategies'

class Hash
  include IS::Deep

  # @return [Hash]
  def deep_dup
    visited_wrap do |visited|
      result = {}
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

  # @return [self]
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

  def can_merge?(other)
    other.is_a?(Hash) || other.respond_to?(:to_hash)
  end

end

class Array
  include IS::Deep

  # @return [Array]
  def deep_dup
    visited_wrap do |visited|
      result = []
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

  # @return [self]
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

  def can_merge? other
    other.is_a?(Array) || other.respond_to?(:to_ary)
  end

end

