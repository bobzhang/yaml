///|
test "parse block maps" {
  let input =
    #|a: 1
    #|b: true
    #|c: hello world
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (Yaml::String("a"), Yaml::Int(1)),
      (Yaml::String("b"), Yaml::Bool(true)),
      (Yaml::String("c"), Yaml::String("hello world")),
    ]),
  )
}

///|
test "parse block sequences" {
  let input =
    #|- 1
    #|- 2
    #|- 3
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Seq([Yaml::Int(1), Yaml::Int(2), Yaml::Int(3)]),
  )
}

///|
test "parse nested block collections" {
  let input =
    #|root:
    #|  - name: first
    #|    value: 1
    #|  - name: second
    #|    value: 2
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("root"),
        Yaml::Seq([
          Yaml::Map([
            (Yaml::String("name"), Yaml::String("first")),
            (Yaml::String("value"), Yaml::Int(1)),
          ]),
          Yaml::Map([
            (Yaml::String("name"), Yaml::String("second")),
            (Yaml::String("value"), Yaml::Int(2)),
          ]),
        ]),
      ),
    ]),
  )
}

///|
test "parse block scalars and negatives" {
  assert_eq(parse_yaml("hello world"), Yaml::String("hello world"))
  assert_eq(parse_yaml("-1"), Yaml::Int(-1))
}
