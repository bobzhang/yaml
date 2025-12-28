///|
test "parse yaml streams" {
  let input =
    #|---
    #|a: 1
    #|...
    #|---
    #|b: 2
    #|
  assert_eq(parse_yaml_stream(input), [
    Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
    Yaml::Map([(Yaml::String("b"), Yaml::Int(2))]),
  ])
}

///|
test "parse yaml rejects multiple documents" {
  let input =
    #|a: 1
    #|---
    #|b: 2
    #|
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::MultipleDocuments(_)) else {
    fail("expected multiple document error")
  }
}

///|
test "parse inline document start" {
  let input =
    #|%YAML 1.2
    #|--- text
    #|
  assert_eq(parse_yaml_stream(input), [Yaml::String("text")])
}
