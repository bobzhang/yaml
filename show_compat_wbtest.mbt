///|
test "legacy Show preserves scalar and nested YAML formatting" {
  let values : Yaml = Seq([
    Null,
    Bool(true),
    Int(3),
    Float(1.5),
    String("a\"b"),
    Binary(b"ab"),
    Map([(String("key"), Seq([Null]))]),
    Alias("ref"),
    Anchor(name="anchor", value=String("raw")),
    Tagged(tag="!tag", value=String("value")),
  ])
  assert_eq(
    values.to_string(),
    "Seq([Null, Bool(true), Int(3), Float(1.5), String(a\"b), Binary(b\"ab\"), Map([(String(key), Seq([Null]))]), Alias(ref), Anchor(name=anchor, value=String(raw)), Tagged(tag=!tag, value=String(value))])",
  )
}

///|
test "legacy Show preserves positions and labeled errors" {
  let pos : Position = { line: 2, column: 4, }
  assert_eq(pos.to_string(), "{line: 2, column: 4}")
  assert_eq(
    ParseError::UnexpectedChar(pos~, found='x').to_string(),
    "UnexpectedChar(pos={line: 2, column: 4}, found=x)",
  )
  assert_eq(
    ParseError::InvalidTagValue(tag="!tag", value="hello").to_string(),
    "InvalidTagValue(tag=!tag, value=hello)",
  )
  assert_eq(
    ParseError::MultipleDocuments(count=2).to_string(),
    "MultipleDocuments(count=2)",
  )
}
