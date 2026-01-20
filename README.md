# Baked File System

Include (bake them) static files into a binary at compile time and access them anytime you need.

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  baked_file_system:
    github: schovi/baked_file_system
    version: 0.10.0
```

## Usage

A custom type that extends `BakedFileSystem` is used as a file system. The macro `bake_folder` bakes all files in
a given path into the virtual file system. Both relative and absolute paths are supported, as well as baking multiple
folders.

```crystal
require "baked_file_system"

class FileStorage
  extend BakedFileSystem

  bake_folder "/home/my_name/work/crystal_project/public"
  bake_folder "../public"
end

```

Files can be loaded using `get` and `get?` class methods.

```crystal
file = FileStorage.get("path/to/file.png")

file.gets_to_end  # returns content of file
file.path         # returns path of file
file.size         # returns size of original file
```

When try to get missing file, `get` raises a `BakedFileSystem::NoSuchFileError` exception
while `get?` returns `nil`.

```crystal
begin
  FileStorage.get "missing/file"
rescue BakedFileSystem::NoSuchFileError
  puts "File #{path} is missing"
end

FileStorage.get? "missing/file" # => nil
```

## Faster Compilation with objcopy

By default, files are embedded as Crystal string literals. For projects with many or large baked files, this can significantly increase compile time.

As an alternative, you can use the `-Dobjcopy` compiler flag to embed files using `objcopy`, which converts binary files to C object files that are linked into your binary. This can provide substantial compile time improvements (30%+ faster in some cases).

```crystal
# Build with objcopy for faster compilation
crystal build --release -Dobjcopy src/my_app.cr
```

Or run specs with objcopy:

```crystal
crystal spec -Dobjcopy
```

**Requirements:** The `-Dobjcopy` mode requires `objcopy` and `ar` utilities to be available on your system. These are typically installed with `binutils` (Linux) or `Xcode Command Line Tools` (macOS).

**How it works:** Instead of generating large Crystal string literals, the objcopy mode:
1. Compresses files with gzip
2. Uses `objcopy` to convert each file to an object file with C symbols
3. Combines object files into a static library using `ar`
4. Links the library into your binary with C bindings

The API and behavior remain identical - just faster compilation!

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/schovi/baked_file_system/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [schovi](https://github.com/schovi) David Schovanec
- [straight-shoota](https://github.com/straight-shoota) Johannes Müller
