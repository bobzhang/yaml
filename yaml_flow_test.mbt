///|
test "parse flow scalars" {
  assert_eq(@yaml.parse_yaml("null"), @yaml.Yaml::Null)
  assert_eq(@yaml.parse_yaml("~"), @yaml.Yaml::Null)
  assert_eq(@yaml.parse_yaml("true"), @yaml.Yaml::Bool(true))
  assert_eq(@yaml.parse_yaml("false"), @yaml.Yaml::Bool(false))
  assert_eq(@yaml.parse_yaml("42"), @yaml.Yaml::Int(42))
  assert_eq(@yaml.parse_yaml("3.5"), @yaml.Yaml::Float(3.5))
  assert_eq(@yaml.parse_yaml("1_000"), @yaml.Yaml::Int(1000))
  assert_eq(@yaml.parse_yaml("0x10"), @yaml.Yaml::Int(16))
  assert_eq(@yaml.parse_yaml("0o10"), @yaml.Yaml::Int(8))
  assert_eq(@yaml.parse_yaml("0b10"), @yaml.Yaml::Int(2))
  assert_eq(@yaml.parse_yaml("\"hi\""), @yaml.Yaml::String("hi"))
  assert_eq(@yaml.parse_yaml("'hi'"), @yaml.Yaml::String("hi"))
  assert_eq(@yaml.parse_yaml("\"1\""), @yaml.Yaml::String("1"))
  assert_eq(@yaml.parse_yaml("'2'"), @yaml.Yaml::String("2"))
  assert_eq(
    @yaml.parse_yaml("\"line\\nnext\""),
    @yaml.Yaml::String("line\nnext"),
  )
  let continued =
    #|"line\
    #|  next"
  assert_eq(@yaml.parse_yaml(continued), @yaml.Yaml::String("linenext"))
  let folded_double =
    #|"a
    #|  b"
  assert_eq(@yaml.parse_yaml(folded_double), @yaml.Yaml::String("a b"))
  let folded_single =
    #|'a
    #|  b'
  assert_eq(@yaml.parse_yaml(folded_single), @yaml.Yaml::String("a b"))
  assert_eq(@yaml.parse_yaml("\"a\\N b\""), @yaml.Yaml::String("a\u{0085} b"))
  assert_eq(
    @yaml.parse_yaml("[hello world]"),
    @yaml.Yaml::Seq([@yaml.Yaml::String("hello world")]),
  )
  assert_eq(
    @yaml.parse_yaml("[http://example.com]"),
    @yaml.Yaml::Seq([@yaml.Yaml::String("http://example.com")]),
  )
  assert_eq(
    @yaml.parse_yaml("[foo#bar]"),
    @yaml.Yaml::Seq([@yaml.Yaml::String("foo#bar")]),
  )
}

///|
test "parse flow plain multiline scalars" {
  let input =
    #|[a
    #|  b]
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Seq([@yaml.Yaml::String("a b")]),
  )
}

///|
test "parse special floats" {
  match @yaml.parse_yaml(".inf") {
    Float(value) => assert_true(value.is_inf())
    _ => fail("expected float")
  }
}

///|
test "parse flow collections" {
  assert_eq(
    @yaml.parse_yaml("[1, 2, 3]"),
    @yaml.Yaml::Seq([@yaml.Yaml::Int(1), @yaml.Yaml::Int(2), @yaml.Yaml::Int(3)]),
  )
  assert_eq(
    @yaml.parse_yaml("[1,,2]"),
    @yaml.Yaml::Seq([@yaml.Yaml::Int(1), @yaml.Yaml::Null, @yaml.Yaml::Int(2)]),
  )
  assert_eq(
    @yaml.parse_yaml("{a: 1, b: [true, null]}"),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("a"), @yaml.Yaml::Int(1)),
      (
        @yaml.Yaml::String("b"),
        @yaml.Yaml::Seq([@yaml.Yaml::Bool(true), @yaml.Yaml::Null]),
      ),
    ]),
  )
  assert_eq(
    @yaml.parse_yaml("{a:, b: 1}"),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("a"), @yaml.Yaml::Null),
      (@yaml.Yaml::String("b"), @yaml.Yaml::Int(1)),
    ]),
  )
  assert_eq(
    @yaml.parse_yaml("{: 1}"),
    @yaml.Yaml::Map([(@yaml.Yaml::Null, @yaml.Yaml::Int(1))]),
  )
  assert_eq(
    @yaml.parse_yaml("{:}"),
    @yaml.Yaml::Map([(@yaml.Yaml::Null, @yaml.Yaml::Null)]),
  )
  assert_eq(
    @yaml.parse_yaml("{a, b:}"),
    @yaml.Yaml::Map([
      (@yaml.Yaml::String("a"), @yaml.Yaml::Null),
      (@yaml.Yaml::String("b"), @yaml.Yaml::Null),
    ]),
  )
  assert_eq(
    @yaml.parse_yaml("{hello world: 1}"),
    @yaml.Yaml::Map([(@yaml.Yaml::String("hello world"), @yaml.Yaml::Int(1))]),
  )
  assert_eq(
    @yaml.parse_yaml("[a: 1]"),
    @yaml.Yaml::Seq([
      @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
    ]),
  )
}

///|
test "parse flow explicit keys" {
  assert_eq(
    @yaml.parse_yaml("{? a: b}"),
    @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::String("b"))]),
  )
}

///|
test "parse flow comments" {
  assert_eq(
    @yaml.parse_yaml("[1, # one\n2]"),
    @yaml.Yaml::Seq([@yaml.Yaml::Int(1), @yaml.Yaml::Int(2)]),
  )
  assert_eq(
    @yaml.parse_yaml("{a: 1} # trailing"),
    @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
  )
}

///|
test "parse double-quoted leading tabs" {
  let escaped = "\"2 leading\n    \\\t" + "tab\""
  assert_eq(@yaml.parse_yaml(escaped), @yaml.Yaml::String("2 leading \ttab"))
  let literal = "\"3 leading\n    \t" + "tab\""
  assert_eq(@yaml.parse_yaml(literal), @yaml.Yaml::String("3 leading tab"))
}
