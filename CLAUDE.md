# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test

- This project uses Swift Package Manager.
- Tests are powered by Swift Testing, using the `#expect` and `#require` macros.

## Code Style

- This project adheres to the Swift 6 concurrency model. Use actors and Sendable types where appropriate, and avoid `@unchecked Sendable` and `nonisolated` keywords.
