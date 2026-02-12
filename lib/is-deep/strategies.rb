# frozen_string_literal: true

require_relative 'core'

# Namespace for array merge strategies.
#
# Strategies are callable objects (lambdas or class instances with #call)
# that determine how two arrays should be merged.
#
# @example Using built-in strategies
#   IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE
#   IS::Deep.array_strategy = IS::Deep::ArrayStrategies::UNION
#
# @example Using KeyBased strategy
#   strategy = IS::Deep::ArrayStrategies::KeyBased.new(:id)
#   data.deep_merge(other, array_strategy: strategy)
#
module IS::Deep::ArrayStrategies

  # Replace strategy: other array replaces base entirely.
  #
  REPLACE = lambda { |_, other| other }

  # Concat strategy: append other to base (default).
  #
  # Preserves duplicates and order.
  #
  CONCAT = lambda { |base, other| base + other }

  # Union strategy: combine arrays removing duplicates.
  #
  # Uses == for equality comparison. Order is preserved from base,
  # then unique elements from other are appended.
  #
  UNION = lambda { |base, other| base | other }

  # Key-based merge strategy for arrays of hashes.
  #
  # Matches elements by specified or auto-detected key, then deep merges
  # matching elements. Unmatched elements are appended.
  #
  # @example Auto-detect key from common candidates (:id, :name, :key, :env, :host)
  #   strategy = IS::Deep::ArrayStrategies::KeyBased.new
  #   [{ id: 1, val: 1 }].deep_merge([{ id: 1, val: 2 }], array_strategy: strategy)
  #   # => [{ id: 1, val: 2 }]
  #
  # @example Explicit key
  #   strategy = IS::Deep::ArrayStrategies::KeyBased.new(:service_name)
  #
  class KeyBased

    # @private
    DEFAULT_KEY_CANDIDATES = [:id, :name, :key, :env, :host].freeze

    # Initialize with optional explicit key.
    #
    # @param key [Symbol, String, nil] Key for matching elements.
    #   If nil, attempts auto-detection from first element.
    def initialize key = nil
      @key = key
    end

    # Execute merge strategy.
    #
    # @param base [Array] Original array
    # @param other [Array] Array to merge into base
    # @return [Array] Merged result
    # @note Falls back to CONCAT behavior if key cannot be determined
    def call base, other
      effective_key = @key || detect_key(base)

      unless effective_key
        # Fallback к concat если не можем определить ключ
        return base + other
      end

      indexed = index_by_key(base, effective_key)
      merge_indexed base.dup, other, indexed, effective_key
    end

    private

    def detect_key base
      return nil if base.empty?
      return nil unless base.first.is_a?(Hash)

      DEFAULT_KEY_CANDIDATES.find { |k| base.first.key?(k) }
    end

    def index_by_key array, key
      indexed = {}
      array.each do |elem|
        next unless elem.is_a?(Hash)
        k = elem[key]
        indexed[k] = elem unless k.nil?
      end
      indexed
    end

    def merge_indexed result, other, indexed, key
      other.each do |elem|
        unless elem.is_a?(Hash)
          result << elem
          next
        end

        k = elem[key]
        if k && indexed.key?(k) && indexed[k].respond_to?(:deep_merge)
          idx = result.index(indexed[k])
          result[idx] = indexed[k].deep_merge(elem)
        else
          result << elem
        end
      end

      result
    end
  end

  # Predefined KeyBased instances for common keys.
  KEY_BASED = {
    detect: KeyBased::new(nil),
    id: KeyBased::new(:id),
    name: KeyBased::new(:name),
    key: KeyBased::new(:key),
    host: KeyBased::new(:host),
  }

end
