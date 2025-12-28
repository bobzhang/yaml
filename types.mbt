///|
struct Position {
  line : Int
  column : Int
} derive(Eq, Show, ToJson)

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
  MultipleDocuments(count~ : Int)
  NotImplemented(feature~ : String)
} derive(Eq, Show, ToJson)

///|
pub(all) enum Yaml {
  Null
  Bool(Bool)
  Int(Int)
  Float(Float)
  String(String)
  Seq(Array[Yaml])
  Map(Array[(Yaml, Yaml)])
  Alias(String)
  Anchor(name~ : String, value~ : Yaml)
  Tagged(tag~ : String, value~ : Yaml)
} derive(Eq, Show, ToJson)
