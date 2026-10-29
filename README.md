# bobzhang/yaml

A YAML parser written in MoonBit, targeting YAML 1.2. It supports block and flow
collections, quoted and block scalars, document streams, tags, anchors, aliases,
merge keys, and binary values. It works on the native, JavaScript, Wasm, and
Wasm GC backends.

## Install

```sh
moon add bobzhang/yaml
```

Add the package to your `moon.pkg`:

```moonbit
import {
  "bobzhang/yaml",
}
```

## Parse a document

```moonbit
fn main {
  let document = try! @yaml.parse_yaml("name: MoonBit\nenabled: true\n")
  match document {
    Map(entries) => {
      for entry in entries {
        let (key, value) = entry
        println("\{key}: \{value}")
      }
    }
    _ => println("Expected a mapping")
  }
}
```

`parse_yaml` returns a `Yaml` value and raises `ParseError` for invalid input or
multiple documents. Empty input returns `Null`. The example uses `try!` to keep
it short; applications can handle errors with `try ... catch` or propagate them
from a function declared with `raise @yaml.ParseError`.

`Yaml` represents nulls, booleans, 32-bit integers, floating-point values,
strings, bytes, sequences, mappings, and tagged values. Mappings are arrays of
key/value pairs, allowing non-string keys and preserving entry order. This is a
parser; it does not provide a general YAML serializer.

## Streams and aliases

- `parse_yaml_stream(text)` parses every document, replaces aliases with their
  referenced values, and applies merge keys. Anchor and tag wrappers remain in
  the returned tree.
- `parse_yaml_stream_raw(text)` retains `Anchor`, `Alias`, and `Tagged` nodes.
- `resolve_aliases(value)` resolves a raw tree and raises `ParseError` for
  unresolved anchors or invalid merges.
- `decode_base64(tag, text)` and `encode_base64(bytes)` provide binary conversion.

## Validation

```sh
moon check --target all
moon test --target all
moon fmt --check
```

CI also runs the YAML test suite at pinned commit
`6ad3d2c62885d82fc349026c136ef560838fdf3d`. To run the same corpus locally:

```sh
git clone https://github.com/yaml/yaml-test-suite.git yaml-test-suite-data
git -C yaml-test-suite-data checkout 6ad3d2c62885d82fc349026c136ef560838fdf3d
moon build --target native
python3 scripts/run_yaml_suite.py
```

The first release passes 59 module tests on each backend and all 402 cases
reported by that corpus runner. This describes the tested corpus, rather than a
claim that every YAML feature or implementation edge case is covered.

## License

Apache License 2.0. See [LICENSE](LICENSE).
