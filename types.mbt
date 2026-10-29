///|
struct Position {
  line : Int32
  column : Int32
} derive(Eq, Show, ToJson, Debug)

///|
pub(all) suberror ParseError {
  UnexpectedChar(pos~ : Position, found~ : Char)
  UnexpectedEof(pos~ : Position)
  InvalidIndent(pos~ : Position)
  InvalidNumber(pos~ : Position, value~ : String)
  InvalidEscape(pos~ : Position, value~ : String)
  UnknownAnchor(name~ : String)
  InvalidMerge(detail~ : String)
  InvalidDirective(detail~ : String)
  InvalidTagValue(tag~ : String, value~ : String)
  MultipleDocuments(count~ : Int32)
  NotImplemented(feature~ : String)
} derive(Eq, Show, ToJson, Debug)

///|
pub(all) enum Yaml {
  Null
  Bool(Bool)
  Int(Int32)
  Float(Double)
  String(String)
  Binary(Bytes)
  Seq(Array[Yaml])
  Map(Array[(Yaml, Yaml)])
  Alias(String)
  Anchor(name~ : String, value~ : Yaml)
  Tagged(tag~ : String, value~ : Yaml)
} derive(Eq, Show, ToJson, Debug)
