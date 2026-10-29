///|
test "merge key with anchor" {
  let input =
    #|base: &base {a: 1, b: 2}
    #|child:
    #|  <<: *base
    #|  b: 3
    #|
  assert_eq(
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("base"),
        @yaml.Yaml::Anchor(
          name="base",
          value=@yaml.Yaml::Map([
            (@yaml.Yaml::String("a"), @yaml.Yaml::Int(1)),
            (@yaml.Yaml::String("b"), @yaml.Yaml::Int(2)),
          ]),
        ),
      ),
      (
        @yaml.Yaml::String("child"),
        @yaml.Yaml::Map([
          (@yaml.Yaml::String("a"), @yaml.Yaml::Int(1)),
          (@yaml.Yaml::String("b"), @yaml.Yaml::Int(3)),
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
    @yaml.parse_yaml(input),
    @yaml.Yaml::Map([
      (
        @yaml.Yaml::String("base"),
        @yaml.Yaml::Anchor(
          name="base",
          value=@yaml.Yaml::Map([(@yaml.Yaml::String("a"), @yaml.Yaml::Int(1))]),
        ),
      ),
      (
        @yaml.Yaml::String("extra"),
        @yaml.Yaml::Anchor(
          name="extra",
          value=@yaml.Yaml::Map([(@yaml.Yaml::String("b"), @yaml.Yaml::Int(2))]),
        ),
      ),
      (
        @yaml.Yaml::String("child"),
        @yaml.Yaml::Map([
          (@yaml.Yaml::String("a"), @yaml.Yaml::Int(1)),
          (@yaml.Yaml::String("b"), @yaml.Yaml::Int(2)),
          (@yaml.Yaml::String("c"), @yaml.Yaml::Int(3)),
        ]),
      ),
    ]),
  )
}
