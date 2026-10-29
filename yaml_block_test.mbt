///|
test "parse block maps" {
  let input =
    #|a: 1
    #|b: true
    #|c: hello world
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("a"), @yaml.Yaml::Int(1)),
      (@yaml.Yaml::String("b"), @yaml.Yaml::Bool(true)),
      (@yaml.Yaml::String("c"), @yaml.Yaml::String("hello world")),
    ]),
  )
}

///|
test "parse empty mapping keys" {
  let input =
    #|: a
    #|: b
    #|
  let docs = @yaml.parse_yaml_stream_raw(input)
  guard docs.length() == 1 else { fail("expected single doc") }
  assert_eq(
    docs[0],
    @yaml.Yaml::Map([
      (@yaml.Yaml::Null, @yaml.Yaml::String("a")),
      (@yaml.Yaml::Null, @yaml.Yaml::String("b")),
    ]),
  )
}

///|
test "parse bom at start" {
  let input = "\u{feff}a: 1"
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Seq([@yaml.Yaml::Int(1), @yaml.Yaml::Int(2), @yaml.Yaml::Int(3)]),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("root"),
        @yaml.Yaml::Seq([
          @yaml.Yaml::Map([
            (@yaml.Yaml::String("name"), @yaml.Yaml::String("first")),
            (@yaml.Yaml::String("value"), @yaml.Yaml::Int(1)),
          ]),
          @yaml.Yaml::Map([
            (@yaml.Yaml::String("name"), @yaml.Yaml::String("second")),
            (@yaml.Yaml::String("value"), @yaml.Yaml::Int(2)),
          ]),
        ]),
      ),
    ]),
  )
}

///|
test "parse nested block sequences" {
  let input =
    #|- - a
    #|  - b
    #|- c
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Seq([
      @yaml.Yaml::Seq([@yaml.Yaml::String("a"), @yaml.Yaml::String("b")]),
      @yaml.Yaml::String("c"),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("key"),
        @yaml.Yaml::Seq([@yaml.Yaml::String("a"), @yaml.Yaml::String("b")]),
      ),
    ]),
  )
}

///|
test "parse tagged indentless sequences" {
  let input =
    #|sequence: !!seq
    #|- entry
    #|- nested
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("sequence"),
        @yaml.Yaml::Tagged(
          tag="tag:yaml.org,2002:seq",
          value=@yaml.Yaml::Seq([
            @yaml.Yaml::String("entry"),
            @yaml.Yaml::String("nested"),
          ]),
        ),
      ),
    ]),
  )
}

///|
test "reject inline sequence after key" {
  let input =
    #|key: - a
    #|     - b
    #|
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent error")
  }
}

///|
test "parse block scalars and negatives" {
  assert_eq(@yaml.parse_yaml("hello world"), @yaml.Yaml::String("hello world"))
  assert_eq(@yaml.parse_yaml("-1"), @yaml.Yaml::Int(-1))
}

///|
test "parse top-level multiline plain scalars" {
  let input =
    #|hello
    #|world
    #|
  assert_eq(@yaml.parse_yaml(input), @yaml.Yaml::String("hello world"))
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
    @yaml.parse_yaml(literal_input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("literal"), @yaml.Yaml::String(literal_value)),
    ]),
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
    @yaml.parse_yaml(folded_input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("folded"), @yaml.Yaml::String(folded_value)),
    ]),
  )
  let strip_input =
    #|strip: |-
    #|  a
    #|
  assert_eq(
    @yaml.parse_yaml(strip_input),
    @yaml.Yaml::Map([(@yaml.Yaml::String("strip"), @yaml.Yaml::String("a"))]),
  )
  let keep_input =
    #|keep: |+
    #|  a
    #|
    #|
  let keep_value = "a\n\n"
  assert_eq(
    @yaml.parse_yaml(keep_input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("keep"), @yaml.Yaml::String(keep_value)),
    ]),
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
    @yaml.parse_yaml(indent_input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("indented"), @yaml.Yaml::String(indent_value)),
    ]),
  )
}

///|
test "parse multiline quoted scalars" {
  let folded_input = "\"\n  foo\n\"\n"
  assert_eq(@yaml.parse_yaml(folded_input), @yaml.Yaml::String(" foo "))
  let empty_space = "'\n  '\n"
  assert_eq(@yaml.parse_yaml(empty_space), @yaml.Yaml::String(" "))
  let empty_line = "'\n\n  '\n"
  assert_eq(@yaml.parse_yaml(empty_line), @yaml.Yaml::String("\n"))
}

///|
test "parse empty block scalar with chomp keep" {
  let input =
    #|empty: |+
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([(@yaml.Yaml::String("empty"), @yaml.Yaml::String("\n"))]),
  )
}

///|
test "reject invalid block scalar indicators" {
  let zero_input =
    #|a: |0
    #|  b
    #|
  let zero_result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(zero_input),
  ) catch {
    err => Err(err)
  }
  guard zero_result is Err(@yaml.ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent indicator error")
  }
  let multi_digit_input =
    #|a: |10
    #|  b
    #|
  let multi_result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(multi_digit_input),
  ) catch {
    err => Err(err)
  }
  guard multi_result is Err(@yaml.ParseError::InvalidIndent(_)) else {
    fail("expected invalid indent indicator error")
  }
  let trailing_input =
    #|a: |1---
    #|  b
    #|
  let trailing_result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(trailing_input),
  ) catch {
    err => Err(err)
  }
  guard trailing_result is Err(@yaml.ParseError::InvalidIndent(_)) else {
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("key1"), @yaml.Yaml::String("value1")),
      (
        @yaml.Yaml::Map([
          (@yaml.Yaml::String("key2"), @yaml.Yaml::String("value2")),
        ]),
        @yaml.Yaml::Null,
      ),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::Seq([@yaml.Yaml::String("a"), @yaml.Yaml::String("b")]),
        @yaml.Yaml::Int(1),
      ),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("key"), @yaml.Yaml::String("line1 line2 line3")),
    ]),
  )
}

///|
test "reject mapping in multiline plain scalar" {
  let input =
    #|this
    #| is
    #|  invalid: x
    #|
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidIndent(_)) else {
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([(@yaml.Yaml::String("key"), @yaml.Yaml::String("value"))]),
  )
}

///|
test "parse multiline plain scalars in sequences" {
  let input =
    #|- line1
    #|  line2
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Seq([@yaml.Yaml::String("line1 line2")]),
  )
}

///|
test "parse anchored nested values" {
  let input =
    #|root: &node
    #|  key: 1
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("root"),
        @yaml.Yaml::Anchor(
          name="node",
          value=@yaml.Yaml::Map([
            (@yaml.Yaml::String("key"), @yaml.Yaml::Int(1)),
          ]),
        ),
      ),
    ]),
  )
}
