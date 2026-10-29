///|
test "parse yaml streams" {
  let input =
    #|---
    #|a: 1
    #|...
    #|---
    #|b: 2
    #|
  assert_eq(@yaml.parse_yaml_stream(input), [
    @yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
    @yaml.Yaml::Map([(@yaml.Yaml::String("b"), @yaml.Yaml::Int(2))]),
  ])
}

///|
test "parse yaml rejects multiple documents" {
  let input =
    #|a: 1
    #|---
    #|b: 2
    #|
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::MultipleDocuments(_)) else {
    fail("expected multiple document error")
  }
}

///|
test "parse inline document start" {
  let input =
    #|%YAML 1.2
    #|--- text
    #|
  assert_eq(@yaml.parse_yaml_stream(input), [@yaml.Yaml::String("text")])
}
