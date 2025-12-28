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
  while scanner.peek() is Some(c) && !is_flow_plain_break(scanner, c) {
    ignore(scanner.advance())
    sb.write_char(c)
  }
  let raw = sb.to_string().trim_end().to_string()
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
fn is_flow_plain_break(scanner : Scanner, c : Char) -> Bool {
  if c is '\n' || c is '\r' || c is '\t' {
    return true
  }
  if c is ',' || c is ']' || c is '}' || c is '[' || c is '{' {
    return true
  }
  if c is '#' {
    return true
  }
  if c is ':' {
    match scanner.peek_next() {
      None => true
      Some(next) =>
        next.is_whitespace() || next is ',' || next is ']' || next is '}'
    }
  } else {
    false
  }
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
  let normalized = raw.replace_all(old="_", new="")
  let lowered = normalized.to_lower()
  match parse_special_float(lowered) {
    Some(value) => return Some(Yaml::Float(Float::from_double(value)))
    None => ()
  }
  let mut has_digit = false
  for c in normalized {
    if c.is_ascii_digit() {
      has_digit = true
    }
  }
  if !has_digit {
    return None
  }
  let (sign, body) = strip_sign(normalized)
  if body.has_prefix("0x") || body.has_prefix("0X") {
    return parse_int_base(body.view(start_offset=2).to_string(), 16, sign)
  }
  if body.has_prefix("0o") || body.has_prefix("0O") {
    return parse_int_base(body.view(start_offset=2).to_string(), 8, sign)
  }
  if body.has_prefix("0b") || body.has_prefix("0B") {
    return parse_int_base(body.view(start_offset=2).to_string(), 2, sign)
  }
  let has_float = lowered.contains(".") ||
    lowered.contains("e") ||
    lowered.contains("E")
  if has_float {
    try @strconv.parse_double(lowered[:]) catch {
      _ => None
    } noraise {
      value => Some(Yaml::Float(Float::from_double(value)))
    }
  } else {
    try @strconv.parse_int(lowered[:]) catch {
      _ => None
    } noraise {
      value => Some(Yaml::Int(value))
    }
  }
}

///|
fn strip_sign(value : String) -> (Int, String) {
  if value.has_prefix("-") {
    (-1, value.view(start_offset=1).to_string())
  } else if value.has_prefix("+") {
    (1, value.view(start_offset=1).to_string())
  } else {
    (1, value)
  }
}

///|
fn parse_int_base(digits : String, base : Int, sign : Int) -> Yaml? {
  try @strconv.parse_int(digits[:], base~) catch {
    _ => None
  } noraise {
    value => Some(Yaml::Int(value * sign))
  }
}

///|
fn parse_special_float(lowered : String) -> Double? {
  if lowered is ".inf" || lowered is "+.inf" || lowered is "-.inf" {
    let sign = if lowered.has_prefix("-") { -1.0 } else { 1.0 }
    try @strconv.parse_double("inf") catch {
      _ => None
    } noraise {
      value => Some(value * sign)
    }
  } else if lowered is ".nan" || lowered is "+.nan" || lowered is "-.nan" {
    try @strconv.parse_double("nan") catch {
      _ => None
    } noraise {
      value => Some(value)
    }
  } else {
    None
  }
}
