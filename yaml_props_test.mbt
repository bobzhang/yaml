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
test "parse core tagged scalars" {
  assert_eq(
    parse_yaml("!!str 3"),
    Yaml::Tagged(tag="tag:yaml.org,2002:str", value=Yaml::String("3")),
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
