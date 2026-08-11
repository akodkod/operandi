# Changelog

## Unreleased

### Added

- Add `Operandi::RuntimeError` with access to the failed service instance
- Add the associated service class to `Operandi::ArgTypeError`
- Add `Operandi::Messages#full_messages`
- Add Ruby 4.0 support

### Changed

- Reduce the published gem to runtime and user-facing support files

### Fixed

- Load Operandi without relying on other gems to require `forwardable`
- Remove formatting artifacts from plain Ruby type errors
- Keep `run!` configuration scoped to a single context-wrapper invocation
- Do not report `stop_immediately!` and `fail_immediately!` as step crashes
- Do not retry a crashing step marked with `always: true`

### Breaking changes

- Remove deprecated methods: `done!`, `done?`, `arguments` and `outputs` methods
- Drop Ruby 3.1 support; Ruby 3.2 or later is now required

## 4.0.0 (2026-01-01)

### Added

- Allow to specify `parent: true` for `step` to skip `StepMethodExists` Rubocop cop

### Breaking changes

- Rename gem from `light-services to `operandi`
  Reason: No folder nesting. The gem isn't really "light" anymore anyway.

- Removed dry-types support. Sorbet runtime types are now the recommended type system for advanced type validation. Plain Ruby class types continue to work as before.
 
- The `run` and `run!` methods now accept only keyword arguments, passing a hash as the first argument is no longer supported.

## 3.3.1 (2025-12-16)

### Added

- Sorbet runtime type support for `arg` and `output` (validation only, no coercion)

## 3.3.0 (2025-12-15)

### Added

- Sorbet and Tapioca support for `arg` and `output`

## 3.2.1 (2025-12-15)

### Added

- Add RuboCop cop `ReservedName`

## 3.2.0 (2025-12-15)

### Added

- Add Cursor rules
- Add `successful?` as an alias for `success?`
- Add RuboCop cop `PreferFailMethod` to detect `errors.add(:base, "message")` and suggest using `fail!("message")` instead

### Breaking changes

- Service runs steps with `always: true` after `fail_immediately!` was called

## 3.1.2 (2025-12-14)

### Added

- Add `fail!` and `fail_immediately!` helpers

### Changed

- Split `config.require_type` into `config.require_arg_type` and `config.require_output_type`

## 3.1.1 (2025-12-14)

### Added

- Better IDE support for callbacks DSL

## 3.1.0 (2025-12-13)

### Breaking changes

- Enforce arguments and output types by default. Use `config.require_arg_type = false` and `config.require_output_type = false` to disable this behavior. The convenience setter `config.require_type = false` sets both options at once for backward compatibility.

### Added

- `stop!` and `stopped?` methods for early exit (renamed from `done!` and `done?`)
- `stop_immediately!` method for immediate execution halt within the current step
- `done!` and `done?` are deprecated, but remain available as aliases for backward compatibility
- Ruby LSP support with step navigation and indexing
- Rubocop cops `StepMethodExists`, `ConditionMethodExists`, `DslOrder`, `MissingPrivateKeyword`, `NoDirectInstantiation`, `ArgumentTypeRequired`, `OutputTypeRequired`, `DeprecatedMethods`
- Comprehensive YARD documentation

## 3.0.0 (2025-12-12)

### Breaking changes

- Removed support for symbol types (e.g., `:array`, `:hash`, `:boolean`). Use Ruby classes (e.g., `Array`, `Hash`, `[TrueClass, FalseClass]`) or dry-types
- Removed `benchmark: true` option
- Removed `verbose: true` option
- Bumped minimum supported Ruby version to **3.0**.
- Removed `errors.copy_to`

### Added

- Output type validation
- dry-types support for arguments and outputs (with coercion and constraints)
- Callback system (service + step callbacks)
- Built-in RSpec matchers for services
- Name validation for arguments, steps, and outputs
- `run` method fallback when no steps are defined

### Documentation

- Documentation moved into this repository and refreshed to match v3 behavior
