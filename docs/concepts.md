# Concepts

This section covers the core concepts of Operandi: **Arguments**, **Steps**, **Outputs**, **Context**, **Errors**, and **Callbacks**.

## Service Execution Flow

When you call `MyService.run(args)`, the following happens:

```
┌──────────────────────────────────────────────────────────────┐
│                      Service.run(args)                       │
├──────────────────────────────────────────────────────────────┤
│  1. Load default values for arguments and outputs            │
│  2. Validate argument types                                  │
│  3. Run before_service_run callbacks                         │
├──────────────────────────────────────────────────────────────┤
│  4. Begin around_service_run callback                        │
│  5. Begin database transaction (if use_transactions: true)   │
│     ┌─────────────────────────────────────────────────────┐  │
│     │  6. Execute steps in order                          │  │
│     │     - Run before_step_run / around_step_run         │  │
│     │     - Execute step method                           │  │
│     │     - Run after_step_run / on_step_success          │  │
│     │     - Skip if condition (if:/unless:) not met       │  │
│     │     - Stop if errors.break? is true                 │  │
│     │     - Stop if stop! was called                      │  │
│     ├─────────────────────────────────────────────────────┤  │
│     │  7. On error → Rollback transaction                 │  │
│     │     On success → Commit transaction                 │  │
│     └─────────────────────────────────────────────────────┘  │
│  8. End around_service_run callback                          │
├──────────────────────────────────────────────────────────────┤
│  9. Run steps marked with always: true (unless stop! called) │
│ 10. Validate output types (if success)                       │
│ 11. Copy errors/warnings to parent service (if in context)   │
│ 12. Run after_service_run callback                           │
│ 13. Run on_service_success or on_service_failure callback    │
├──────────────────────────────────────────────────────────────┤
│ 14. Return service instance                                  │
│     - service.success? / service.failed?                     │
│     - service.output / service.errors                        │
└──────────────────────────────────────────────────────────────┘
```

## Arguments

Arguments are the inputs provided to a service when it is invoked. They can be validated by type, assigned default values, and be designated as optional or required.

[Read more about arguments](arguments.md)

## Steps

Steps are the fundamental units of work within a service, representing each individual task a service performs. They can be executed conditionally or skipped.

[Read more about steps](steps.md)

## Outputs

Outputs are the results produced by a service upon its completion. They can have default values and be validated by type.

[Read more about outputs](outputs.md)

## Context

Context refers to the shared state that passes between services in a service chain, enabling the transfer of arguments and error states from one service to another.

[Read more about context](context.md)

## Errors

Errors occur during service execution and cause execution to halt. When an error occurs, all services in the same context chain stop, and database transactions are rolled back (configurable).

[Read more about errors](errors.md)

## Callbacks

Callbacks allow you to run custom code at specific points during service and step execution. They're perfect for logging, benchmarking, auditing, and other cross-cutting concerns.

[Read more about callbacks](callbacks.md)
