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
  NotImplemented(feature~ : String)
} derive(Eq, Show, ToJson)

///|
pub enum Yaml {
  Null
  Bool(Bool)
  Int(Int)
  Float(Float)
  String(String)
  Seq(Array[Yaml])
  Map(Array[(Yaml, Yaml)])
} derive(Eq, Show, ToJson)

///|
pub fn parse_yaml(_input : String) -> Yaml raise ParseError {
  raise ParseError::NotImplemented(feature="parser")
}
