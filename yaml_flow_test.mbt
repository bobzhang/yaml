///|
test "parse flow scalars" {
  assert_eq(parse_yaml("null"), Yaml::Null)
  assert_eq(parse_yaml("~"), Yaml::Null)
  assert_eq(parse_yaml("true"), Yaml::Bool(true))
  assert_eq(parse_yaml("false"), Yaml::Bool(false))
  assert_eq(parse_yaml("42"), Yaml::Int(42))
  assert_eq(parse_yaml("3.5"), Yaml::Float(Float::from_double(3.5)))
  assert_eq(parse_yaml("\"hi\""), Yaml::String("hi"))
  assert_eq(parse_yaml("'hi'"), Yaml::String("hi"))
  assert_eq(parse_yaml("\"line\\nnext\""), Yaml::String("line\nnext"))
}

///|
test "parse flow collections" {
  assert_eq(
    parse_yaml("[1, 2, 3]"),
    Yaml::Seq([Yaml::Int(1), Yaml::Int(2), Yaml::Int(3)]),
  )
  assert_eq(
    parse_yaml("{a: 1, b: [true, null]}"),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Int(1)),
      (Yaml::String("b"), Yaml::Seq([Yaml::Bool(true), Yaml::Null])),
    ]),
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
