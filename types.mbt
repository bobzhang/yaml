///|
struct Position {
  line : Int32
  column : Int32
} derive(Eq, ToJson, Debug)

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
} derive(Eq, ToJson, Debug)

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
} derive(Eq, ToJson, Debug)

///|
pub extend ParseError with Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
pub extend ParseError with Show::{to_string, output}

///|
pub extend ParseError with ToJson::{to_json}

///|
pub extend Position with Debug::{to_repr}

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with Show::{to_string, output}

///|
pub extend Position with ToJson::{to_json}

///|
pub extend Yaml with Debug::{to_repr}

///|
pub extend Yaml with Eq::{not_equal, equal}

///|
pub extend Yaml with Show::{to_string, output}

///|
pub extend Yaml with ToJson::{to_json}

///|
pub impl Show for Position with fn output(self, logger) {
  logger.write_string("{")
  logger.write_string("line: ")
  logger.write_object(self.line)
  logger.write_string(", column: ")
  logger.write_object(self.column)
  logger.write_string("}")
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    UnexpectedChar(pos=arg0, found=arg1) => {
      logger.write_string("UnexpectedChar(")
      logger.write_string("pos=")
      logger.write_object(arg0)
      logger.write_string(", found=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
    UnexpectedEof(pos=arg0) => {
      logger.write_string("UnexpectedEof(")
      logger.write_string("pos=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    InvalidIndent(pos=arg0) => {
      logger.write_string("InvalidIndent(")
      logger.write_string("pos=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    InvalidNumber(pos=arg0, value=arg1) => {
      logger.write_string("InvalidNumber(")
      logger.write_string("pos=")
      logger.write_object(arg0)
      logger.write_string(", value=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
    InvalidEscape(pos=arg0, value=arg1) => {
      logger.write_string("InvalidEscape(")
      logger.write_string("pos=")
      logger.write_object(arg0)
      logger.write_string(", value=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
    UnknownAnchor(name=arg0) => {
      logger.write_string("UnknownAnchor(")
      logger.write_string("name=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    InvalidMerge(detail=arg0) => {
      logger.write_string("InvalidMerge(")
      logger.write_string("detail=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    InvalidDirective(detail=arg0) => {
      logger.write_string("InvalidDirective(")
      logger.write_string("detail=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    InvalidTagValue(tag=arg0, value=arg1) => {
      logger.write_string("InvalidTagValue(")
      logger.write_string("tag=")
      logger.write_object(arg0)
      logger.write_string(", value=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
    MultipleDocuments(count=arg0) => {
      logger.write_string("MultipleDocuments(")
      logger.write_string("count=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    NotImplemented(feature=arg0) => {
      logger.write_string("NotImplemented(")
      logger.write_string("feature=")
      logger.write_object(arg0)
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for Yaml with fn output(self, logger) {
  match self {
    Null => logger.write_string("Null")
    Bool(arg0) => {
      logger.write_string("Bool(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    Int(arg0) => {
      logger.write_string("Int(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    Float(arg0) => {
      logger.write_string("Float(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    String(arg0) => {
      logger.write_string("String(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    Binary(arg0) => {
      logger.write_string("Binary(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    Seq(arg0) => {
      logger.write_string("Seq(")
      logger.write_string("[")
      for i23, value23 in arg0 {
        if i23 > 0 {
          logger.write_string(", ")
        }
        logger.write_object(value23)
      }
      logger.write_string("]")
      logger.write_string(")")
    }
    Map(arg0) => {
      logger.write_string("Map(")
      logger.write_string("[")
      for i25, value25 in arg0 {
        if i25 > 0 {
          logger.write_string(", ")
        }
        logger.write_string("(")
        logger.write_object(value25.0)
        logger.write_string(", ")
        logger.write_object(value25.1)
        logger.write_string(")")
      }
      logger.write_string("]")
      logger.write_string(")")
    }
    Alias(arg0) => {
      logger.write_string("Alias(")
      logger.write_object(arg0)
      logger.write_string(")")
    }
    Anchor(name=arg0, value=arg1) => {
      logger.write_string("Anchor(")
      logger.write_string("name=")
      logger.write_object(arg0)
      logger.write_string(", value=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
    Tagged(tag=arg0, value=arg1) => {
      logger.write_string("Tagged(")
      logger.write_string("tag=")
      logger.write_object(arg0)
      logger.write_string(", value=")
      logger.write_object(arg1)
      logger.write_string(")")
    }
  }
}
