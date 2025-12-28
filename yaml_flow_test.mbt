///|
test "parse flow scalars" {
  assert_eq(parse_yaml("null"), Yaml::Null)
  assert_eq(parse_yaml("~"), Yaml::Null)
  assert_eq(parse_yaml("true"), Yaml::Bool(true))
  assert_eq(parse_yaml("false"), Yaml::Bool(false))
  assert_eq(parse_yaml("42"), Yaml::Int(42))
  assert_eq(parse_yaml("3.5"), Yaml::Float(Float::from_double(3.5)))
  assert_eq(parse_yaml("1_000"), Yaml::Int(1000))
  assert_eq(parse_yaml("0x10"), Yaml::Int(16))
  assert_eq(parse_yaml("0o10"), Yaml::Int(8))
  assert_eq(parse_yaml("0b10"), Yaml::Int(2))
  assert_eq(parse_yaml("\"hi\""), Yaml::String("hi"))
  assert_eq(parse_yaml("'hi'"), Yaml::String("hi"))
  assert_eq(parse_yaml("\"line\\nnext\""), Yaml::String("line\nnext"))
  let continued =
    #|"line\
    #|  next"
  assert_eq(parse_yaml(continued), Yaml::String("linenext"))
  let folded_double =
    #|"a
    #|  b"
  assert_eq(parse_yaml(folded_double), Yaml::String("a b"))
  let folded_single =
    #|'a
    #|  b'
  assert_eq(parse_yaml(folded_single), Yaml::String("a b"))
  assert_eq(parse_yaml("\"a\\N b\""), Yaml::String("a\u{0085} b"))
  assert_eq(
    parse_yaml("[hello world]"),
    Yaml::Seq([Yaml::String("hello world")]),
  )
  assert_eq(
    parse_yaml("[http://example.com]"),
    Yaml::Seq([Yaml::String("http://example.com")]),
  )
  assert_eq(parse_yaml("[foo#bar]"), Yaml::Seq([Yaml::String("foo#bar")]))
}

///|
test "parse flow plain multiline scalars" {
  let input =
    #|[a
    #|  b]
  assert_eq(
    parse_yaml(input),
    Yaml::Seq([Yaml::String("a b")]),
  )
}

///|
test "parse special floats" {
  match parse_yaml(".inf") {
    Float(value) => assert_true(value.is_inf())
    _ => fail("expected float")
  }
}

///|
test "parse flow collections" {
  assert_eq(
    parse_yaml("[1, 2, 3]"),
    Yaml::Seq([Yaml::Int(1), Yaml::Int(2), Yaml::Int(3)]),
  )
  assert_eq(
    parse_yaml("[1,,2]"),
    Yaml::Seq([Yaml::Int(1), Yaml::Null, Yaml::Int(2)]),
  )
  assert_eq(
    parse_yaml("{a: 1, b: [true, null]}"),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Int(1)),
      (Yaml::String("b"), Yaml::Seq([Yaml::Bool(true), Yaml::Null])),
    ]),
  )
  assert_eq(
    parse_yaml("{a:, b: 1}"),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Null),
      (Yaml::String("b"), Yaml::Int(1)),
    ]),
  )
  assert_eq(
    parse_yaml("{: 1}"),
    Yaml::Map([(Yaml::Null, Yaml::Int(1))]),
  )
  assert_eq(
    parse_yaml("{:}"),
    Yaml::Map([(Yaml::Null, Yaml::Null)]),
  )
  assert_eq(
    parse_yaml("{hello world: 1}"),
    Yaml::Map([(Yaml::String("hello world"), Yaml::Int(1))]),
  )
}

///|
test "parse flow explicit keys" {
  assert_eq(
    parse_yaml("{? a: b}"),
    Yaml::Map([(Yaml::String("a"), Yaml::String("b"))]),
  )
}

///|
test "parse flow comments" {
  assert_eq(
    parse_yaml("[1, # one\n2]"),
    Yaml::Seq([Yaml::Int(1), Yaml::Int(2)]),
  )
  assert_eq(
    parse_yaml("{a: 1} # trailing"),
    Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
  )
}
