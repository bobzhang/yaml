///|
fn parse_double_quoted(scanner : Scanner) -> String raise ParseError {
  scanner.expect('"')
  let lines : Array[String] = []
  let sb = StringBuilder::new()
  while true {
    match scanner.peek() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some('"') => {
        ignore(scanner.advance())
        lines.push(sb.to_string())
        let folded = fold_quoted_lines(lines)
        return unescape_double_quoted(folded)
      }
      Some('\\') => {
        ignore(scanner.advance())
        match scanner.peek() {
          Some('\n') => skip_escaped_line_break(scanner)
          Some('\r') => skip_escaped_line_break(scanner)
          Some(c) => {
            sb.write_char('\\')
            sb.write_char(c)
            ignore(scanner.advance())
          }
          None => raise ParseError::UnexpectedEof(pos=scanner.position())
        }
      }
      Some('\n') => {
        ignore(scanner.advance())
        lines.push(sb.to_string())
        sb.reset()
        skip_quoted_indent(scanner)
      }
      Some('\r') => {
        ignore(scanner.advance())
        lines.push(sb.to_string())
        sb.reset()
        skip_quoted_indent(scanner)
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
  let lines : Array[String] = []
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
          lines.push(sb.to_string())
          return fold_quoted_lines(lines)
        }
      }
      Some('\n') => {
        ignore(scanner.advance())
        lines.push(sb.to_string())
        sb.reset()
        skip_quoted_indent(scanner)
      }
      Some('\r') => {
        ignore(scanner.advance())
        lines.push(sb.to_string())
        sb.reset()
        skip_quoted_indent(scanner)
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
  let lines : Array[String] = []
  let sb = StringBuilder::new()
  let mut prev_space = true
  let mut ended_on_newline = false
  while scanner.peek() is Some(c) &&
        !is_flow_plain_break(scanner, c, prev_space) {
    if c is '\n' || c is '\r' {
      ignore(scanner.advance())
      lines.push(sb.to_string().trim_end().to_string())
      sb.reset()
      ended_on_newline = true
      if !skip_flow_plain_line(scanner, lines) {
        break
      }
      ended_on_newline = false
      prev_space = true
      continue
    }
    ignore(scanner.advance())
    sb.write_char(c)
    prev_space = c.is_whitespace()
  }
  if scanner.peek() is Some('#') && prev_space {
    scanner.skip_comment()
  }
  if lines.length() == 0 {
    let raw = sb.to_string().trim_end().to_string()
    if raw is "" {
      match scanner.peek() {
        None => raise ParseError::UnexpectedEof(pos=scanner.position())
        Some(c) =>
          raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
      }
    }
    raw
  } else {
    if !ended_on_newline {
      lines.push(sb.to_string().trim_end().to_string())
    }
    let folded = fold_lines(lines)
    if folded is "" {
      match scanner.peek() {
        None => raise ParseError::UnexpectedEof(pos=scanner.position())
        Some(c) =>
          raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
      }
    }
    folded
  }
}

///|
fn fold_quoted_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut all_empty = true
  for line in lines {
    if !(line is "") {
      all_empty = false
      break
    }
  }
  if all_empty {
    if lines.length() == 2 {
      return " "
    }
    let mut count = lines.length() - 2
    if count < 0 {
      count = 0
    }
    let sb = StringBuilder::new()
    for _ in 0..<count {
      sb.write_char('\n')
    }
    return sb.to_string()
  }
  let mut trailing = 0
  while trailing < lines.length() &&
        lines[lines.length() - 1 - trailing] is "" {
    trailing = trailing + 1
  }
  let end = lines.length() - trailing
  let mut trailing_space = false
  let mut trailing_newlines = 0
  if trailing > 0 {
    let mut has_content = false
    for i in 0..<end {
      if !(lines[i] is "") {
        has_content = true
        break
      }
    }
    if has_content {
      if trailing == 1 {
        trailing_space = true
      } else {
        trailing_newlines = trailing - 1
      }
    }
  }
  let sb = StringBuilder::new()
  let mut last_ended_space = false
  let mut i = 0
  if i < end && lines[i] is "" {
    let mut has_content = false
    for j in (i + 1)..<end {
      if !(lines[j] is "") {
        has_content = true
        break
      }
    }
    if has_content {
      sb.write_char(' ')
      last_ended_space = true
    }
    i = i + 1
  }
  while i < end {
    let line = lines[i]
    if line is "" {
      let mut j = i
      while j < end && lines[j] is "" {
        j = j + 1
      }
      for _ in i..<j {
        sb.write_char('\n')
      }
      last_ended_space = false
      i = j
      continue
    }
    let text =
      if i + 1 == end {
        line
      } else {
        trim_end_whitespace(line)
      }
    sb.write_string(text)
    last_ended_space = ends_with_space(text)
    if i + 1 < end &&
      !(lines[i + 1] is "") &&
      !ends_with_space(text) {
      sb.write_char(' ')
      last_ended_space = true
    }
    i = i + 1
  }
  for _ in 0..<trailing_newlines {
    sb.write_char('\n')
    last_ended_space = false
  }
  if trailing_space && !last_ended_space {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
fn unescape_double_quoted(text : String) -> String raise ParseError {
  let scanner = Scanner::new(text)
  let sb = StringBuilder::new()
  while scanner.peek() is Some(c) {
    if c is '\\' {
      ignore(scanner.advance())
      match scanner.peek() {
        Some('\n') => skip_escaped_line_break(scanner)
        Some('\r') => skip_escaped_line_break(scanner)
        _ => sb.write_char(parse_escape(scanner))
      }
      continue
    }
    ignore(scanner.advance())
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn trim_end_whitespace(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c is ' ' || c is '\t' {
      if end > 1 && chars[end - 2] is '\\' {
        break
      }
      end = end - 1
      continue
    }
    break
  }
  if end == chars.length() {
    return text
  }
  let sb = StringBuilder::new()
  for i in 0..<end {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
fn ends_with_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let last = chars[chars.length() - 1]
  last is ' '
}

///|
fn is_flow_plain_break(scanner : Scanner, c : Char, prev_space : Bool) -> Bool {
  if c is '\t' {
    return true
  }
  if c is ',' || c is ']' || c is '}' || c is '[' || c is '{' {
    return true
  }
  if c is '#' && prev_space {
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
fn skip_flow_plain_line(
  scanner : Scanner,
  lines : Array[String],
) -> Bool {
  while true {
    while scanner.peek() is Some(c) && (c is ' ' || c is '\t') {
      ignore(scanner.advance())
    }
    match scanner.peek() {
      None => return false
      Some('\n') => {
        ignore(scanner.advance())
        lines.push("")
        continue
      }
      Some('\r') => {
        ignore(scanner.advance())
        lines.push("")
        continue
      }
      Some('#') => {
        scanner.skip_comment()
        match scanner.peek() {
          Some('\n') => {
            ignore(scanner.advance())
            return false
          }
          Some('\r') => {
            ignore(scanner.advance())
            return false
          }
          None => return false
          Some(_) => return false
        }
      }
      Some(c) =>
        if is_flow_plain_break(scanner, c, true) {
          return false
        } else {
          return true
        }
    }
  }
  false
}

///|
fn parse_escape(scanner : Scanner) -> Char raise ParseError {
  match scanner.advance() {
    None => raise ParseError::UnexpectedEof(pos=scanner.position())
    Some('0') => '\u{0000}'
    Some('a') => '\u{0007}'
    Some('b') => '\u{0008}'
    Some('t') => '\t'
    Some('\t') => '\t'
    Some('n') => '\n'
    Some('v') => '\u{000b}'
    Some('f') => '\u{000c}'
    Some('r') => '\r'
    Some('e') => '\u{001b}'
    Some('N') => '\u{0085}'
    Some('_') => '\u{00a0}'
    Some('L') => '\u{2028}'
    Some('P') => '\u{2029}'
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
fn skip_escaped_line_break(scanner : Scanner) -> Unit {
  if scanner.peek() is Some('\r') {
    ignore(scanner.advance())
    if scanner.peek() is Some('\n') {
      ignore(scanner.advance())
    }
  } else if scanner.peek() is Some('\n') {
    ignore(scanner.advance())
  }
  while scanner.peek() is Some(c) && (c is ' ' || c is '\t') {
    ignore(scanner.advance())
  }
}

///|
fn skip_quoted_indent(scanner : Scanner) -> Unit {
  while scanner.peek() is Some(c) && (c is ' ' || c is '\t') {
    ignore(scanner.advance())
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
  match scanner.peek() {
    Some('"') => Yaml::String(parse_double_quoted(scanner))
    Some('\'') => Yaml::String(parse_single_quoted(scanner))
    _ => parse_scalar_value(parse_plain_scalar(scanner))
  }
}

///|
fn parse_scalar_value(raw : String) -> Yaml {
  if raw is "" {
    return Yaml::Null
  }
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
    Some(value) => return Some(Yaml::Float(value))
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
      value => Some(Yaml::Float(value))
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
