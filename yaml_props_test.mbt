///|
test "parse anchors and aliases" {
  let input =
    #|a: &id 1
    #|b: *id
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("a"),
        @yaml.Yaml::Anchor(name="id", value=@yaml.Yaml::Int(1)),
      ),
      (@yaml.Yaml::String("b"), @yaml.Yaml::Int(1)),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("a"),
        @yaml.Yaml::Anchor(name="id+1", value=@yaml.Yaml::Int(1)),
      ),
      (@yaml.Yaml::String("b"), @yaml.Yaml::Int(1)),
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
  let docs = @yaml.parse_yaml_stream_raw(input)
  guard docs.length() == 1 else { fail("expected single doc") }
  assert_eq(
    docs[0],
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::Anchor(name="a:", value=@yaml.Yaml::String("key")),
        @yaml.Yaml::Anchor(name="a", value=@yaml.Yaml::String("value")),
      ),
      (@yaml.Yaml::String("foo"), @yaml.Yaml::Alias("a:")),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:set",
      value=@yaml.Yaml::Map([
        (@yaml.Yaml::String("Mark McGwire"), @yaml.Yaml::Null),
        (@yaml.Yaml::String("Sammy Sosa"), @yaml.Yaml::Null),
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
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("v1"),
        @yaml.Yaml::Tagged(tag="!tag", value=@yaml.Yaml::String("hello")),
      ),
      (
        @yaml.Yaml::String("v2"),
        @yaml.Yaml::Anchor(
          name="a",
          value=@yaml.Yaml::Tagged(tag="!other", value=@yaml.Yaml::Int(2)),
        ),
      ),
    ]),
  )
}

///|
test "explicit tags keep plain scalars as strings" {
  assert_eq(
    @yaml.parse_yaml("!foo 3"),
    @yaml.Yaml::Tagged(tag="!foo", value=@yaml.Yaml::Int(3)),
  )
  assert_eq(
    @yaml.parse_yaml("! 3"),
    @yaml.Yaml::Tagged(tag="!", value=@yaml.Yaml::Int(3)),
  )
}

///|
test "parse binary tag" {
  assert_eq(
    @yaml.parse_yaml("!!binary YWJj"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:binary",
      value=@yaml.Yaml::Binary(b"abc"),
    ),
  )
  let input =
    #|!!binary |
    #|  YWJj
    #|  ZGVm
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:binary",
      value=@yaml.Yaml::Binary(b"abcdef"),
    ),
  )
}

///|
test "reject invalid binary tag" {
  let input = "!!binary \"@@\""
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse timestamp tag" {
  assert_eq(
    @yaml.parse_yaml("!!timestamp 2001-12-15"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:timestamp",
      value=@yaml.Yaml::String("2001-12-15"),
    ),
  )
  assert_eq(
    @yaml.parse_yaml("!!timestamp 2001-12-15T02:59:43.1Z"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:timestamp",
      value=@yaml.Yaml::String("2001-12-15T02:59:43.1Z"),
    ),
  )
}

///|
test "reject invalid timestamp tag" {
  let input = "!!timestamp 2023-13-01"
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse set tag" {
  assert_eq(
    @yaml.parse_yaml("!!set {a:, b:}"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:set",
      value=@yaml.Yaml::Map([
        (@yaml.Yaml::String("a"), @yaml.Yaml::Null),
        (@yaml.Yaml::String("b"), @yaml.Yaml::Null),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("value"),
        @yaml.Yaml::Tagged(
          tag="tag:yaml.org,2002:str",
          value=@yaml.Yaml::String("a b"),
        ),
      ),
    ]),
  )
}

///|
test "reject invalid set tag" {
  let input = "!!set {a: 1}"
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse pairs and omap tags" {
  assert_eq(
    @yaml.parse_yaml("!!pairs [{a: 1}, {b: 2}]"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:pairs",
      value=@yaml.Yaml::Seq([
        @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
        @yaml.Yaml::Map([(@yaml.Yaml::String("b"), @yaml.Yaml::Int(2))]),
      ]),
    ),
  )
  assert_eq(
    @yaml.parse_yaml("!!omap [{a: 1}, {b: 2}]"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:omap",
      value=@yaml.Yaml::Seq([
        @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
        @yaml.Yaml::Map([(@yaml.Yaml::String("b"), @yaml.Yaml::Int(2))]),
      ]),
    ),
  )
}

///|
test "reject invalid omap tag" {
  let input = "!!omap [{a: 1}, {a: 2}]"
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse map and seq tags" {
  assert_eq(
    @yaml.parse_yaml("!!map {a: 1}"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:map",
      value=@yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
    ),
  )
  assert_eq(
    @yaml.parse_yaml("!!seq [1, 2]"),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:seq",
      value=@yaml.Yaml::Seq([@yaml.Yaml::Int(1), @yaml.Yaml::Int(2)]),
    ),
  )
}

///|
test "reject invalid map and seq tags" {
  let map_input = "!!map [1]"
  let map_result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(map_input),
  ) catch {
    err => Err(err)
  }
  guard map_result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
  let seq_input = "!!seq {a: 1}"
  let seq_result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(seq_input),
  ) catch {
    err => Err(err)
  }
  guard seq_result is Err(@yaml.ParseError::InvalidTagValue(_)) else {
    fail("expected invalid tag value error")
  }
}

///|
test "parse core tagged scalars" {
  assert_eq(
    @yaml.parse_yaml("!!str 3"),
    @yaml.Yaml::Tagged(tag="tag:yaml.org,2002:str", value=@yaml.Yaml::Int(3)),
  )
  assert_eq(
    @yaml.parse_yaml("!!int \"3\""),
    @yaml.Yaml::Tagged(tag="tag:yaml.org,2002:int", value=@yaml.Yaml::Int(3)),
  )
  assert_eq(
    @yaml.parse_yaml("!!bool \"true\""),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:bool",
      value=@yaml.Yaml::Bool(true),
    ),
  )
}

///|
test "parse flow props" {
  assert_eq(
    @yaml.parse_yaml("[&a 1, *a]"),
    @yaml.Yaml::Seq([
      @yaml.Yaml::Anchor(name="a", value=@yaml.Yaml::Int(1)),
      @yaml.Yaml::Int(1),
    ]),
  )
}
