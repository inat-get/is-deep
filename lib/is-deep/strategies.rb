# frozen_string_literal: true

require_relative 'core'

module IS::Deep::ArrayStrategies

  REPLACE = lambda { |_, other| other }

  CONCAT = lambda { |base, other| base + other }

  UNION = lambda { |base, other| base | other }

  class KeyBased
    
    DEFAULT_KEY_CANDIDATES = [:id, :name, :key, :env, :host].freeze

    def initialize key = nil
      @key = key
    end

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

  KEY_BASED = {
    detect: KeyBased::new(nil),
    id: KeyBased::new(:id),
    name: KeyBased::new(:name),
    key: KeyBased::new(:key),
    host: KeyBased::new(:host),
  }

end
