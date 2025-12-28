///|
fn is_plain_break(c : Char) -> Bool {
  c.is_whitespace() ||
  c is ',' ||
  c is ':' ||
  c is '[' ||
  c is ']' ||
  c is '{' ||
  c is '}' ||
  c is '#'
}

///|
fn parse_double_quoted(scanner : Scanner) -> String raise ParseError {
  scanner.expect('"')
  let sb = StringBuilder::new()
  while true {
    match scanner.peek() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some('"') => {
        ignore(scanner.advance())
        return sb.to_string()
      }
      Some('\\') => {
        ignore(scanner.advance())
        sb.write_char(parse_escape(scanner))
      }
      Some(c) => {
        ignore(scanner.advance())
        sb.write_char(c)
      }
    }
  } else {
    sb.to_string()
  }
}

///|
fn parse_single_quoted(scanner : Scanner) -> String raise ParseError {
  scanner.expect('\'')
  let sb = StringBuilder::new()
  while true {
    match scanner.peek() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some('\'') => {
        ignore(scanner.advance())
        if scanner.peek() is Some('\'') {
          ignore(scanner.advance())
          sb.write_char('\'')
        } else {
          return sb.to_string()
        }
      }
      Some(c) => {
        ignore(scanner.advance())
        sb.write_char(c)
      }
    }
  } else {
    sb.to_string()
  }
}

///|
fn parse_plain_scalar(scanner : Scanner) -> String raise ParseError {
  let sb = StringBuilder::new()
  while scanner.peek() is Some(c) && !is_plain_break(c) {
    ignore(scanner.advance())
    sb.write_char(c)
  }
  let raw = sb.to_string()
  if raw is "" {
    match scanner.peek() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some(c) =>
        raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
    }
  }
  raw
}

///|
fn parse_escape(scanner : Scanner) -> Char raise ParseError {
  match scanner.advance() {
    None => raise ParseError::UnexpectedEof(pos=scanner.position())
    Some('0') => '\u{0000}'
    Some('a') => '\u{0007}'
    Some('b') => '\u{0008}'
    Some('t') => '\t'
    Some('n') => '\n'
    Some('v') => '\u{000b}'
    Some('f') => '\u{000c}'
    Some('r') => '\r'
    Some('e') => '\u{001b}'
    Some(' ') => ' '
    Some('"') => '"'
    Some('\\') => '\\'
    Some('/') => '/'
    Some('x') => {
      let code = read_hex(scanner, 2)
      char_from_code(code, scanner)
    }
    Some('u') => {
      let code = read_hex(scanner, 4)
      char_from_code(code, scanner)
    }
    Some('U') => {
      let code = read_hex(scanner, 8)
      char_from_code(code, scanner)
    }
    Some(other) =>
      raise ParseError::InvalidEscape(
        pos=scanner.position(),
        value=other.to_string(),
      )
  }
}

///|
fn read_hex(scanner : Scanner, digits : Int) -> Int raise ParseError {
  let mut value = 0
  for _ in 0..<digits {
    match scanner.advance() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some(c) =>
        match hex_value(c) {
          None =>
            raise ParseError::InvalidEscape(
              pos=scanner.position(),
              value=c.to_string(),
            )
          Some(v) => value = value * 16 + v
        }
    }
  }
  value
}

///|
fn hex_value(c : Char) -> Int? {
  if c.is_ascii_digit() {
    Some(c.to_int() - '0'.to_int())
  } else if c.is_ascii_lowercase() {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c.is_ascii_uppercase() {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn char_from_code(code : Int, scanner : Scanner) -> Char raise ParseError {
  match code.to_char() {
    Some(c) => c
    None =>
      raise ParseError::InvalidEscape(
        pos=scanner.position(),
        value=code.to_string(),
      )
  }
}

///|
fn parse_scalar(scanner : Scanner) -> Yaml raise ParseError {
  let raw = match scanner.peek() {
    Some('"') => parse_double_quoted(scanner)
    Some('\'') => parse_single_quoted(scanner)
    _ => parse_plain_scalar(scanner)
  }
  parse_scalar_value(raw)
}

///|
fn parse_scalar_value(raw : String) -> Yaml {
  let lowered = raw.to_lower()
  if lowered is "null" || raw is "~" {
    Yaml::Null
  } else if lowered is "true" {
    Yaml::Bool(true)
  } else if lowered is "false" {
    Yaml::Bool(false)
  } else {
    match parse_number(raw) {
      Some(value) => value
      None => Yaml::String(raw)
    }
  }
}

///|
fn parse_number(raw : String) -> Yaml? {
  let mut has_digit = false
  for c in raw {
    if c.is_ascii_digit() {
      has_digit = true
    }
  }
  if !has_digit {
    return None
  }
  let has_float = raw.contains(".") || raw.contains("e") || raw.contains("E")
  if has_float {
    try @strconv.parse_double(raw[:]) catch {
      _ => None
    } noraise {
      value => Some(Yaml::Float(Float::from_double(value)))
    }
  } else {
    try @strconv.parse_int(raw[:]) catch {
      _ => None
    } noraise {
      value => Some(Yaml::Int(value))
    }
  }
}
