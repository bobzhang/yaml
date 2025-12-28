///|
test "merge key with anchor" {
  let input =
    #|base: &base {a: 1, b: 2}
    #|child:
    #|  <<: *base
    #|  b: 3
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("base"),
        Yaml::Anchor(
          name="base",
          value=Yaml::Map([
            (Yaml::String("a"), Yaml::Int(1)),
            (Yaml::String("b"), Yaml::Int(2)),
          ]),
        ),
      ),
      (
        Yaml::String("child"),
        Yaml::Map([
          (Yaml::String("a"), Yaml::Int(1)),
          (Yaml::String("b"), Yaml::Int(3)),
        ]),
      ),
    ]),
  )
}

///|
test "merge key with sequence" {
  let input =
    #|base: &base {a: 1}
    #|extra: &extra {b: 2}
    #|child:
    #|  <<: [*base, *extra]
    #|  c: 3
    #|
  assert_eq(
    parse_yaml(input),
    Yaml::Map([
      (
        Yaml::String("base"),
        Yaml::Anchor(
          name="base",
          value=Yaml::Map([(Yaml::String("a"), Yaml::Int(1))]),
        ),
      ),
      (
        Yaml::String("extra"),
        Yaml::Anchor(
          name="extra",
          value=Yaml::Map([(Yaml::String("b"), Yaml::Int(2))]),
        ),
      ),
      (
        Yaml::String("child"),
        Yaml::Map([
          (Yaml::String("a"), Yaml::Int(1)),
          (Yaml::String("b"), Yaml::Int(2)),
          (Yaml::String("c"), Yaml::Int(3)),
        ]),
      ),
    ]),
  )
}
