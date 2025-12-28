///|
test "tag directives expand handles" {
  let input =
    #|%TAG !yaml! tag:yaml.org,2002:
    #|---
    #|!yaml!str hello
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Tagged(tag="tag:yaml.org,2002:str", value=Yaml::String("hello")),
  )
}

///|
test "verbatim tags" {
  let input = "!<tag:yaml.org,2002:int> 3"
  assert_eq(
    parse_yaml(input),
    Yaml::Tagged(tag="tag:yaml.org,2002:int", value=Yaml::Int(3)),
  )
}

///|
test "yaml directive" {
  let input =
    #|%YAML 1.2
    #|---
    #|true
    #|
  assert_eq(parse_yaml(input), Yaml::Bool(true))
}

///|
test "reject unsupported yaml version" {
  let input =
    #|%YAML 1.1
    #|---
    #|true
    #|
  let result : Result[Yaml, ParseError] = try? parse_yaml(input)
  guard result is Err(ParseError::InvalidDirective(_)) else {
    fail("expected invalid directive error")
  }
}
