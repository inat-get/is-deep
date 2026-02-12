# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe IS::Deep do
  describe "Hash#deep_merge" do
    it "merges flat hashes" do
      base = { a: 1, b: 2 }
      other = { b: 3, c: 4 }
      expect(base.deep_merge(other)).to eq({ a: 1, b: 3, c: 4 })
      expect(base).to eq({ a: 1, b: 2 }) # не мутирует оригинал
    end

    it "merges nested hashes recursively" do
      base = { x: { a: 1, b: 2 } }
      other = { x: { b: 3, c: 4 } }
      expect(base.deep_merge(other)).to eq({ x: { a: 1, b: 3, c: 4 } })
    end

    it "replaces non-hash values" do
      base = { x: 1 }
      other = { x: "string" }
      expect(base.deep_merge(other)).to eq({ x: "string" })
    end

    it "adds new keys at any level" do
      base = { a: { b: 1 } }
      other = { a: { c: 2 }, d: 3 }
      expect(base.deep_merge(other)).to eq({ a: { b: 1, c: 2 }, d: 3 })
    end

    it "handles empty hashes" do
      expect({}.deep_merge({ a: 1 })).to eq({ a: 1 })
      expect({ a: 1 }.deep_merge({})).to eq({ a: 1 })
    end

    it "converts hash-like objects" do
      struct = Struct.new(:to_hash).new({ a: 1 })
      expect({}.deep_merge(struct)).to eq({ a: 1 })
    end

    it "raises on unsupported types" do
      expect { {}.deep_merge!("string") }.to raise_error(ArgumentError, /Unsupported type/)
    end
  end

  describe "Hash#deep_merge!" do
    it "mutates the receiver" do
      base = { a: 1 }
      base.deep_merge!({ b: 2 })
      expect(base).to eq({ a: 1, b: 2 })
    end
  end

  describe "Hash#deep_dup" do
    it "creates independent copy" do
      base = { a: { b: 1 } }
      copy = base.deep_dup
      copy[:a][:b] = 2
      expect(base[:a][:b]).to eq(1)
    end

    it "preserves default values" do
      base = Hash.new("default")
      base[:a] = 1
      copy = base.deep_dup
      expect(copy.default).to eq("default")
      expect(copy[:unknown]).to eq("default")
    end

    it "preserves default_proc" do
      base = Hash.new { |h, k| h[k] = [] }
      copy = base.deep_dup
      expect(copy.default_proc).to be_a(Proc)
      copy[:x] << 1
      expect(copy[:x]).to eq([1])
    end
  end

  describe "circular reference handling" do
    it "handles circular references in hashes" do
      a = { name: "a" }
      b = { name: "b", ref: a }
      a[:ref] = b

      # Не должно зациклиться
      result = a.deep_dup
      expect(result[:ref][:ref]).to be(result)
    end

    it "handles circular references in arrays" do
      arr = [1, 2]
      arr << arr

      result = arr.deep_dup
      expect(result[2]).to be(result)
    end

    it "handles mixed circular references" do
      h = { arr: [] }
      h[:arr] << h

      result = h.deep_dup
      expect(result[:arr][0]).to be(result)
    end
  end

  describe "Array strategies" do
    describe "REPLACE" do
      let(:strategy) { IS::Deep::ArrayStrategies::REPLACE }

      it "replaces array entirely" do
        base = { x: [1, 2] }
        other = { x: [3, 4] }
        expect(base.deep_merge(other, array_strategy: strategy)).to eq({ x: [3, 4] })
      end

      it "works with nested structures" do
        base = { x: [{ a: 1 }] }
        other = { x: [{ b: 2 }] }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result).to eq({ x: [{ b: 2 }] })
      end
    end

    describe "CONCAT (default)" do
      it "concatenates arrays by default" do
        base = { x: [1, 2] }
        other = { x: [3, 4] }
        expect(base.deep_merge(other)).to eq({ x: [1, 2, 3, 4] })
      end

      it "preserves duplicates" do
        base = { x: [1, 2] }
        other = { x: [2, 3] }
        expect(base.deep_merge(other)).to eq({ x: [1, 2, 2, 3] })
      end
    end

    describe "UNION" do
      let(:strategy) { IS::Deep::ArrayStrategies::UNION }

      it "removes duplicates" do
        base = { x: [1, 2, 3] }
        other = { x: [2, 3, 4] }
        expect(base.deep_merge(other, array_strategy: strategy)).to eq({ x: [1, 2, 3, 4] })
      end
    end

    describe "KeyBased" do
      let(:strategy) { IS::Deep::ArrayStrategies::KeyBased::new }

      it "merges by auto-detected key" do
        base = {
          services: [
            { name: "web", port: 80 },
            { name: "db", port: 5432 },
          ],
        }
        other = {
          services: [
            { name: "web", port: 8080 },
            { name: "cache", port: 6379 },
          ],
        }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result[:services]).to contain_exactly(
          { name: "web", port: 8080 },
          { name: "db", port: 5432 },
          { name: "cache", port: 6379 }
        )
      end

      it "deep merges matched elements" do
        base = {
          items: [
            { id: 1, data: { a: 1, b: 2 } },
          ],
        }
        other = {
          items: [
            { id: 1, data: { b: 3, c: 4 } },
          ],
        }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result[:items].first[:data]).to eq({ a: 1, b: 3, c: 4 })
      end

      it "falls back to concat when no key detected" do
        base = { x: [1, 2] }
        other = { x: [3, 4] }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result).to eq({ x: [1, 2, 3, 4] })
      end

      it "falls back to concat with empty base array" do
        base = { x: [] }
        other = { x: [{ name: "a" }] }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result).to eq({ x: [{ name: "a" }] })
      end

      it "handles mixed element types" do
        base = { x: [{ name: "a", val: 1 }, "string"] }
        other = { x: [{ name: "a", val: 2 }, 42] }
        result = base.deep_merge(other, array_strategy: strategy)
        expect(result[:x]).to eq([{ name: "a", val: 2 }, "string", 42])
      end

      context "with explicit key" do
        let(:strategy) { IS::Deep::ArrayStrategies::KeyBased.new(:service_id) }

        it "uses specified key" do
          base = { x: [{ service_id: "s1", data: "old" }] }
          other = { x: [{ service_id: "s1", data: "new" }] }
          result = base.deep_merge(other, array_strategy: strategy)
          expect(result[:x].first[:data]).to eq("new")
        end
      end

      context "predefined instances" do
        it "uses :id key" do
          base = { x: [{ id: 1, val: "a" }] }
          other = { x: [{ id: 1, val: "b" }] }
          strategy = IS::Deep::ArrayStrategies::KEY_BASED[:id]
          result = base.deep_merge(other, array_strategy: strategy)
          expect(result[:x].first[:val]).to eq("b")
        end
      end
    end
  end

  describe "global array_strategy configuration" do
    after do
      # Сброс к дефолту
      IS::Deep.array_strategy = IS::Deep::ArrayStrategies::CONCAT
    end

    it "uses global strategy when not specified locally" do
      IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE
      base = { x: [1, 2] }
      other = { x: [3] }
      expect(base.deep_merge(other)).to eq({ x: [3] })
    end

    it "local strategy overrides global" do
      IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE
      base = { x: [1, 2] }
      other = { x: [3] }
      result = base.deep_merge(other, array_strategy: IS::Deep::ArrayStrategies::CONCAT)
      expect(result).to eq({ x: [1, 2, 3] })
    end

    it "is thread-local" do
      IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE

      thread_result = nil
      Thread.new do
        IS::Deep.array_strategy = IS::Deep::ArrayStrategies::CONCAT
        thread_result = { x: [1] }.deep_merge({ x: [2] })
      end.join

      expect(thread_result).to eq({ x: [1, 2] })
      # Глобальная не изменилась
      expect(IS::Deep.array_strategy).to eq(IS::Deep::ArrayStrategies::REPLACE)
    end
  end

  describe "Array#deep_merge!" do
    it "mutates the array" do
      base = [1, 2]
      base.deep_merge!([3, 4])
      expect(base).to eq([1, 2, 3, 4])
    end

    it "handles nested hashes in arrays" do
      base = [{ a: 1 }]
      other = [{ b: 2 }]
      base.deep_merge!(other)
      expect(base).to eq([{ a: 1 }, { b: 2 }])
    end

    it "converts array-like objects" do
      struct = Struct.new(:to_ary).new([1, 2])
      expect([].deep_merge(struct)).to eq([1, 2])
    end

    it "raises on unsupported types" do
      expect { [].deep_merge!("string") }.to raise_error(ArgumentError, /Unsupported type/)
    end
  end

  describe "Array#deep_dup" do
    it "creates independent copy" do
      base = [{ a: 1 }]
      copy = base.deep_dup
      copy[0][:a] = 2
      expect(base[0][:a]).to eq(1)
    end

    it "handles nested arrays" do
      base = [[1, 2], [3, 4]]
      copy = base.deep_dup
      copy[0][0] = 99
      expect(base[0][0]).to eq(1)
    end
  end

  describe "complex scenarios" do
    it "handles deeply nested structure" do
      base = {
        level1: {
          level2: {
            level3: {
              data: [1, 2],
              hash: { a: 1 },
            },
          },
        },
      }
      other = {
        level1: {
          level2: {
            level3: {
              data: [3],
              hash: { b: 2 },
            },
          },
        },
      }
      result = base.deep_merge(other)
      expect(result[:level1][:level2][:level3][:data]).to eq([1, 2, 3])
      expect(result[:level1][:level2][:level3][:hash]).to eq({ a: 1, b: 2 })
    end

    it "handles mixed hash and array nesting" do
      base = {
        configs: [
          { name: "app", env: { DEBUG: "0" } },
          { name: "worker", env: { POOL: "5" } },
        ],
      }
      other = {
        configs: [
          { name: "app", env: { DEBUG: "1", API_KEY: "secret" } },
        ],
      }
      result = base.deep_merge(other, array_strategy: IS::Deep::ArrayStrategies::KeyBased.new(:name))

      app_config = result[:configs].find { |c| c[:name] == "app" }
      expect(app_config[:env]).to eq({ DEBUG: "1", API_KEY: "secret" })

      worker_config = result[:configs].find { |c| c[:name] == "worker" }
      expect(worker_config[:env]).to eq({ POOL: "5" })
    end
  end

  describe "edge cases" do
    it "handles nil values" do
      base = { a: nil }
      other = { a: { b: 1 } }
      expect(base.deep_merge(other)).to eq({ a: { b: 1 } })
    end

    it "handles false values" do
      base = { a: false }
      other = { a: true }
      expect(base.deep_merge(other)).to eq({ a: true })
    end

    it "handles empty collections" do
      expect({}.deep_merge({})).to eq({})
      expect([].deep_merge([])).to eq([])
      expect({ a: [] }.deep_merge({ a: [] })).to eq({ a: [] })
    end

    it "preserves original when merging empty other" do
      base = { a: { b: { c: 1 } } }
      expect(base.deep_merge({})).to eq(base)
    end
  end
end
