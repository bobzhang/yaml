///|
test "parse anchors and aliases" {
  let input =
    #|a: &id 1
    #|b: *id
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Anchor(name="id", value=Yaml::Int(1))),
      (Yaml::String("b"), Yaml::Int(1)),
    ]),
  )
}

///|
test "anchors allow punctuation" {
  let input =
    #|a: &id+1 1
    #|b: *id+1
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Anchor(name="id+1", value=Yaml::Int(1))),
      (Yaml::String("b"), Yaml::Int(1)),
    ]),
  )
}

///|
test "anchors allow colons in names" {
  let input =
    #|&a: key: &a value
    #|foo:
    #|  *a:
    #|
  let docs = parse_yaml_stream_raw(input)
  guard docs.length() == 1 else { fail("expected single doc") }
  assert_eq(
    docs[0],
    Yaml::Map([
      (
        Yaml::Anchor(name="a:", value=Yaml::String("key")),
        Yaml::Anchor(name="a", value=Yaml::String("value")),
      ),
      (Yaml::String("foo"), Yaml::Alias("a:")),
    ]),
  )
}

///|
test "tag-only line applies to following block node" {
  let input =
    #|!!set
    #|? Mark McGwire
    #|? Sammy Sosa
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:set",
      value=Yaml::Map([
        (Yaml::String("Mark McGwire"), Yaml::Null),
        (Yaml::String("Sammy Sosa"), Yaml::Null),
      ]),
    ),
  )
}

///|
test "reject duplicate anchors" {
  let input =
    #|top: &a
    #|  &b value
    #|
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected duplicate anchor error")
  }
}

///|
test "parse tags" {
  let input =
    #|v1: !tag hello
    #|v2: !other &a 2
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("v1"),
        Yaml::Tagged(tag="!tag", value=Yaml::String("hello")),
      ),
      (
        Yaml::String("v2"),
        Yaml::Anchor(
          name="a",
          value=Yaml::Tagged(tag="!other", value=Yaml::Int(2)),
        ),
      ),
    ]),
  )
}

///|
test "explicit tags keep plain scalars as strings" {
  assert_eq(parse_yaml("!foo 3"), Yaml::Tagged(tag="!foo", value=Yaml::Int(3)))
  assert_eq(parse_yaml("! 3"), Yaml::Tagged(tag="!", value=Yaml::Int(3)))
}

///|
test "parse binary tag" {
  assert_eq(
    parse_yaml("!!binary YWJj"),
    Yaml::Tagged(tag="tag:yaml.org,2002:binary", value=Yaml::Binary(b"abc")),
  )
  let input =
    #|!!binary |
    #|  YWJj
    #|  ZGVm
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Tagged(tag="tag:yaml.org,2002:binary", value=Yaml::Binary(b"abcdef")),
  )
}

///|
test "reject invalid binary tag" {
  let input = "!!binary \"@@\""
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse timestamp tag" {
  assert_eq(
    parse_yaml("!!timestamp 2001-12-15"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:timestamp",
      value=Yaml::String("2001-12-15"),
    ),
  )
  assert_eq(
    parse_yaml("!!timestamp 2001-12-15T02:59:43.1Z"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:timestamp",
      value=Yaml::String("2001-12-15T02:59:43.1Z"),
    ),
  )
}

///|
test "reject invalid timestamp tag" {
  let input = "!!timestamp 2023-13-01"
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse set tag" {
  assert_eq(
    parse_yaml("!!set {a:, b:}"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:set",
      value=Yaml::Map([
        (Yaml::String("a"), Yaml::Null),
        (Yaml::String("b"), Yaml::Null),
      ]),
    ),
  )
}

///|
test "parse tagged multiline quoted scalar" {
  let input =
    #|value: !!str "a
    #|  b"
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("value"),
        Yaml::Tagged(tag="tag:yaml.org,2002:str", value=Yaml::String("a b")),
      ),
    ]),
  )
}

///|
test "reject invalid set tag" {
  let input = "!!set {a: 1}"
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse pairs and omap tags" {
  assert_eq(
    parse_yaml("!!pairs [{a: 1}, {b: 2}]"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:pairs",
      value=Yaml::Seq([
        Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
        Yaml::Map([(Yaml::String("b"), Yaml::Int(2))]),
      ]),
    ),
  )
  assert_eq(
    parse_yaml("!!omap [{a: 1}, {b: 2}]"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:omap",
      value=Yaml::Seq([
        Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
        Yaml::Map([(Yaml::String("b"), Yaml::Int(2))]),
      ]),
    ),
  )
}

///|
test "reject invalid omap tag" {
  let input = "!!omap [{a: 1}, {a: 2}]"
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse map and seq tags" {
  assert_eq(
    parse_yaml("!!map {a: 1}"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:map",
      value=Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
    ),
  )
  assert_eq(
    parse_yaml("!!seq [1, 2]"),
    Yaml::Tagged(
      tag="tag:yaml.org,2002:seq",
      value=Yaml::Seq([Yaml::Int(1), Yaml::Int(2)]),
    ),
  )
}

///|
test "reject invalid map and seq tags" {
  let map_input = "!!map [1]"
  let map_result : Result[Yaml, ParseError] = try? parse_yaml(map_input)
  guard map_result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
  let seq_input = "!!seq {a: 1}"
  let seq_result : Result[Yaml, ParseError] = try? parse_yaml(seq_input)
  guard seq_result is Err(ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse core tagged scalars" {
  assert_eq(
    parse_yaml("!!str 3"),
    Yaml::Tagged(tag="tag:yaml.org,2002:str", value=Yaml::Int(3)),
  )
  assert_eq(
    parse_yaml("!!int \"3\""),
    Yaml::Tagged(tag="tag:yaml.org,2002:int", value=Yaml::Int(3)),
  )
  assert_eq(
    parse_yaml("!!bool \"true\""),
    Yaml::Tagged(tag="tag:yaml.org,2002:bool", value=Yaml::Bool(true)),
  )
}

///|
test "parse flow props" {
  assert_eq(
    parse_yaml("[&a 1, *a]"),
    Yaml::Seq([Yaml::Anchor(name="a", value=Yaml::Int(1)), Yaml::Int(1)]),
  )
}
