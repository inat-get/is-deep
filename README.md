# is-deep

Deep merge implementation for Ruby with configurable array strategies and circular reference protection.

## Installation

Add to your Gemfile:

```ruby
gem 'is-deep'
```

Or install directly:

```bash
gem install is-deep
```

## Usage

### Basic Deep Merge

```ruby
require 'is-deep'

# Hash merging
base = { a: 1, nested: { x: 1, y: 2 } }
other = { b: 2, nested: { y: 3, z: 4 } }

base.deep_merge(other)
# => { a: 1, b: 2, nested: { x: 1, y: 3, z: 4 } }

# Non-destructive (returns new hash)
result = base.deep_merge(other)
base # unchanged

# Destructive (modifies receiver)
base.deep_merge!(other)
```

### Array Merge Strategies

By default, arrays are concatenated:

```ruby
{ items: [1, 2] }.deep_merge({ items: [3, 4] })
# => { items: [1, 2, 3, 4] }
```

Configure globally:

```ruby
# Replace arrays entirely
IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE
{ items: [1] }.deep_merge({ items: [2] }) # => { items: [2] }

# Union (remove duplicates)
IS::Deep.array_strategy = IS::Deep::ArrayStrategies::UNION
{ items: [1, 2] }.deep_merge({ items: [2, 3] }) # => { items: [1, 2, 3] }
```

Or per-call:

```ruby
{ items: [1] }.deep_merge({ items: [2] }, array_strategy: IS::Deep::ArrayStrategies::REPLACE)
```

### Key-Based Array Merging

For arrays of hashes, merge by matching keys:

```ruby
base = {
  services: [
    { name: 'web', port: 80, env: { DEBUG: '0' } },
    { name: 'db', port: 5432 }
  ]
}

other = {
  services: [
    { name: 'web', port: 8080, env: { DEBUG: '1', API_KEY: 'secret' } },
    { name: 'cache', port: 6379 }
  ]
}

strategy = IS::Deep::ArrayStrategies::KeyBased.new(:name)
base.deep_merge(other, array_strategy: strategy)

# Result:
# {
#   services: [
#     { name: 'web', port: 8080, env: { DEBUG: '1', API_KEY: 'secret' } },
#     { name: 'db', port: 5432 },
#     { name: 'cache', port: 6379 }
#   ]
# }
```

Auto-detect key from common candidates (`:id`, `:name`, `:key`, `:env`, `:host`):

```ruby
strategy = IS::Deep::ArrayStrategies::KeyBased.new
# or use predefined
strategy = IS::Deep::ArrayStrategies::KEY_BASED[:id]
```

### Deep Duplication

Create independent copies with circular reference protection:

```ruby
original = { a: { b: 1 } }
copy = original.deep_dup

copy[:a][:b] = 2
original[:a][:b] # => 1 (unchanged)

# Circular references are handled safely
circular = { name: 'root' }
circular[:self] = circular

copy = circular.deep_dup
copy[:self] # => points to copy itself, not original
```

### Thread Safety

Global strategy is thread-local by default:

```ruby
IS::Deep.array_strategy = IS::Deep::ArrayStrategies::REPLACE

Thread.new do
  # This thread has its own setting
  IS::Deep.array_strategy = IS::Deep::ArrayStrategies::CONCAT
end.join

# Main thread still has REPLACE
```

### Custom Strategies

Implement any callable (lambda or class with `#call`):

```ruby
# Lambda
IS::Deep.array_strategy = ->(base, other) { other.reverse + base }

# Class
class AppendUnique
  def call(base, other)
    (base + other).uniq
  end
end

IS::Deep.array_strategy = AppendUnique.new
```

## API Reference

See [YARD documentation](https://rubydoc.info/gems/is-deep) for complete API.

Key classes:
- `IS::Deep` — configuration and core module
- `IS::Deep::ArrayStrategies` — built-in strategies
- `Hash#deep_merge`, `Hash#deep_merge!`, `Hash#deep_dup`
- `Array#deep_merge`, `Array#deep_merge!`, `Array#deep_dup`

## Requirements

- Ruby >= 3.4

## License

LGPL-3.0-only. See LICENSE file.
