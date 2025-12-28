///|
test "parse block maps" {
  let input =
    #|a: 1
    #|b: true
    #|c: hello world
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Int(1)),
      (Yaml::String("b"), Yaml::Bool(true)),
      (Yaml::String("c"), Yaml::String("hello world")),
    ]),
  )
}

///|
test "parse empty mapping keys" {
  let input =
    #|: a
    #|: b
    #|
  let docs = parse_yaml_stream_raw(input)
  guard docs.length() == 1 else {
    fail("expected single doc")
  }
  assert_eq(
    docs[0],
    Yaml::Map([
      (Yaml::String(""), Yaml::String("a")),
      (Yaml::String(""), Yaml::String("b")),
    ]),
  )
}

///|
test "parse bom at start" {
  let input = "\u{feff}a: 1"
  assert_eq(
    parse_yaml(input),
    Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
  )
}

///|
test "parse block sequences" {
  let input =
    #|- 1
    #|- 2
    #|- 3
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Seq([Yaml::Int(1), Yaml::Int(2), Yaml::Int(3)]),
  )
}

///|
test "parse nested block collections" {
  let input =
    #|root:
    #|  - name: first
    #|    value: 1
    #|  - name: second
    #|    value: 2
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("root"),
        Yaml::Seq([
          Yaml::Map([
            (Yaml::String("name"), Yaml::String("first")),
            (Yaml::String("value"), Yaml::Int(1)),
          ]),
          Yaml::Map([
            (Yaml::String("name"), Yaml::String("second")),
            (Yaml::String("value"), Yaml::Int(2)),
          ]),
        ]),
      ),
    ]),
  )
}

///|
test "parse indentless sequences" {
  let input =
    #|key:
    #|- a
    #|- b
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("key"), Yaml::Seq([Yaml::String("a"), Yaml::String("b")])),
    ]),
  )
}

///|
test "parse block scalars and negatives" {
  assert_eq(parse_yaml("hello world"), Yaml::String("hello world"))
  assert_eq(parse_yaml("-1"), Yaml::Int(-1))
}

///|
test "parse top-level multiline plain scalars" {
  let input =
    #|hello
    #|world
    #|
  assert_eq(parse_yaml(input), Yaml::String("hello world"))
}

///|
test "parse block scalars" {
  let literal_input =
    #|literal: |
    #|  a
    #|  b
    #|
  let literal_value =
    #|a
    #|b
    #|
  assert_eq(
    parse_yaml(literal_input),
    Yaml::Map([(Yaml::String("literal"), Yaml::String(literal_value))]),
  )
  let folded_input =
    #|folded: >
    #|  a
    #|  b
    #|
    #|  c
    #|
  let folded_value =
    #|a b
    #|c
    #|
  assert_eq(
    parse_yaml(folded_input),
    Yaml::Map([(Yaml::String("folded"), Yaml::String(folded_value))]),
  )
  let strip_input =
    #|strip: |-
    #|  a
    #|
  assert_eq(
    parse_yaml(strip_input),
    Yaml::Map([(Yaml::String("strip"), Yaml::String("a"))]),
  )
  let keep_input =
    #|keep: |+
    #|  a
    #|
    #|
  let keep_value =
    #|a
    #|
    #|
    #|
    #|
    #|
  assert_eq(
    parse_yaml(keep_input),
    Yaml::Map([(Yaml::String("keep"), Yaml::String(keep_value))]),
  )
  let indent_input =
    #|indented: |2
    #|  a
    #|  b
    #|
  let indent_value =
    #|a
    #|b
    #|
  assert_eq(
    parse_yaml(indent_input),
    Yaml::Map([(Yaml::String("indented"), Yaml::String(indent_value))]),
  )
}

///|
test "parse empty block scalar with chomp keep" {
  let input =
    #|empty: |+
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([(Yaml::String("empty"), Yaml::String(""))]),
  )
}

///|
test "reject invalid block scalar indicators" {
  let zero_input =
    #|a: |0
    #|  b
    #|
  let zero_result : Result[Yaml, ParseError] = try? parse_yaml(zero_input)
  guard zero_result is Err(ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent indicator error")
  }
  let multi_digit_input =
    #|a: |10
    #|  b
    #|
  let multi_result : Result[Yaml, ParseError] = try? parse_yaml(multi_digit_input)
  guard multi_result is Err(ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent indicator error")
  }
  let trailing_input =
    #|a: |1---
    #|  b
    #|
  let trailing_result : Result[Yaml, ParseError] = try? parse_yaml(trailing_input)
  guard trailing_result is Err(ParseError::InvalidIndent(_)) else {
    fail("expected invalid indicator trailing error")
  }
}

///|
test "parse explicit mapping keys" {
  let input =
    #|? key1
    #|: value1
    #|? key2: value2
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("key1"), Yaml::String("value1")),
      (Yaml::String("key2"), Yaml::String("value2")),
    ]),
  )
}

///|
test "parse explicit key with nested node" {
  let input =
    #|?
    #|  - a
    #|  - b
    #|: 1
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::Seq([Yaml::String("a"), Yaml::String("b")]), Yaml::Int(1)),
    ]),
  )
}

///|
test "parse multiline plain scalars" {
  let input =
    #|key: line1
    #|  line2
    #|  line3
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([(Yaml::String("key"), Yaml::String("line1 line2 line3"))]),
  )
}

///|
test "reject mapping in multiline plain scalar" {
  let input =
    #|this
    #| is
    #|  invalid: x
    #|
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent error")
  }
}

///|
test "parse explicit value indicator" {
  let input =
    #|key
    #|: value
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([(Yaml::String("key"), Yaml::String("value"))]),
  )
}

///|
test "parse multiline plain scalars in sequences" {
  let input =
    #|- line1
    #|  line2
    #|
  assert_eq(parse_yaml(input), Yaml::Seq([Yaml::String("line1 line2")]))
}

///|
test "parse anchored nested values" {
  let input =
    #|root: &node
    #|  key: 1
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("root"),
        Yaml::Anchor(
          name="node",
          value=Yaml::Map([(Yaml::String("key"), Yaml::Int(1))]),
        ),
      ),
    ]),
  )
}
