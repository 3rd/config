SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.PHONY: help install-deps check-types test benchmark format

help:
	@printf '%s\n' 'install-deps  Install locked dependencies' 'check-types   Check the TypeScript SDK and plugins' 'test          Run unit and real-editor tests' 'benchmark     Measure the real host on Linux' 'format        Format Bunvim TypeScript and Lua'

install-deps:
	bun install --frozen-lockfile

check-types:
	bun run typecheck

test:
	bun test

benchmark:
	bun run benchmark

format:
	bun run format
	stylua --config-path ../../linters/stylua.toml lua plugin tests benchmarks
