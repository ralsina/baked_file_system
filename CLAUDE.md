# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BakedFileSystem is a Crystal library that embeds ("bakes") static files into a compiled binary at compile time and provides runtime access via a virtual filesystem interface. Files are gzip-compressed (unless already ending with `.gz`) and stored as string literals in the binary.

## Common Commands

### Building
```bash
shards build          # Build the library
shards install        # Install dependencies
```

### Testing
```bash
crystal spec          # Run all tests
crystal spec spec/baked_file_system_spec.cr  # Run a single test file
```

### Linting
```bash
ameba                 # Run linter
ameba --fix          # Auto-fix linting issues
```

## Architecture

### The Baking Process (Compile-Time)

When a class extends `BakedFileSystem` and calls `bake_folder`:

1. The `bake_folder` macro in `src/baked_file_system.cr:178` invokes the loader binary via `{{ run("./loader", path, dir) }}`
2. `src/loader.cr` (the compiled loader entry point) calls `BakedFileSystem::Loader.load()`
3. `src/loader/loader.cr` scans the directory, recursively collecting all files
4. Each file is gzip-compressed (unless already `.gz`) and encoded as a Crystal string literal via `StringEncoder`
5. Crystal code is generated that calls `bake_file BakedFileSystem::BakedFile.new(...)` for each file
6. This generated code is compiled into the binary

### The Loader Binary

- **Entry point**: `src/loader.cr` - takes path and base directory as ARGV
- **Core logic**: `src/loader/loader.cr` - scans directories, generates Crystal code
- **Encoding**: `src/loader/string_encoder.cr` - efficiently encodes binary data as Crystal string literals

The loader runs at compile time as a separate executable spawned by Crystal's `run()` macro. It outputs Crystal source code to stdout, which is then compiled into the user's binary.

### Runtime Access

- `BakedFileSystem.get(path)` - Returns `BakedFile` or raises `NoSuchFileError`
- `BakedFileSystem.get?(path)` - Returns `BakedFile` or `nil`
- `BakedFileSystem.files` - Returns all baked files

### Key Classes

**`BakedFileSystem::BakedFile`** (`src/baked_file_system.cr:39`):
- Implements `IO` interface for reading file contents
- Handles gzip decompression on-the-fly during reads (unless already compressed)
- Provides `path`, `size`, `compressed?` getters
- Stores data as a `Bytes` slice in memory

**`BakedFileSystem` module** (`src/baked_file_system.cr:22`):
- Extended by user classes to create a baked filesystem
- Maintains `@@files` class variable storing all `BakedFile` instances
- Uses the `extended` macro to initialize `@@files` array
- `bake_folder` macro triggers the compile-time loading process

### Path Handling

- All paths are normalized to start with `/` (both in baking and lookup)
- Path matching uses exact string comparison (no glob patterns)
- Files are stored with their path relative to the baked folder root
- Windows paths are converted to POSIX format using `Path#to_posix`

### Compression

- Files ending with `.gz` are stored as-is (already compressed)
- All other files are gzip-compressed during baking
- Decompression happens transparently on read via `Compress::Gzip::Reader`

## Code Organization

```
src/
├── baked_file_system.cr      # Main module (BakedFileSystem, BakedFile)
├── baked_file_system/
│   └── version.cr            # Version constant (external, do not modify)
├── loader.cr                 # Loader binary entry point
└── loader/
    ├── loader.cr             # Directory scanning and code generation
    └── string_encoder.cr     # Binary-to-string encoding
```

## CI/CD

GitHub Actions (`.github/workflows/main.yml`) tests on:
- Ubuntu (latest and nightly Crystal)
- macOS
- Windows
