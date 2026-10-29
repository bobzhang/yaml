///|
test "tag directives expand handles" {
  let input =
    #|%TAG !yaml! tag:yaml.org,2002:
    #|---
    #|!yaml!str hello
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Tagged(
      tag="tag:yaml.org,2002:str",
      value=@yaml.Yaml::String("hello"),
    ),
  )
}

///|
test "verbatim tags" {
  let input = "!<tag:yaml.org,2002:int> 3"
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Tagged(tag="tag:yaml.org,2002:int", value=@yaml.Yaml::Int(3)),
  )
}

///|
test "yaml directive" {
  let input =
    #|%YAML 1.2
    #|---
    #|true
    #|
  assert_eq(@yaml.parse_yaml(input), @yaml.Yaml::Bool(true))
}

///|
test "reject unsupported yaml version" {
  let input =
    #|%YAML 2.0
    #|---
    #|true
    #|
  let result : Result[@yaml.Yaml, @yaml.ParseError] = Ok(
    @yaml.parse_yaml(input),
  ) catch {
    err => Err(err)
  }
  guard result is Err(@yaml.ParseError::InvalidDirective(_)) else {
    fail("expected invalid directive error")
  }
}

///|
test "ignore unknown directives" {
  let input =
    #|%FOO bar baz
    #|---
    #|true
    #|
  assert_eq(@yaml.parse_yaml(input), @yaml.Yaml::Bool(true))
}
