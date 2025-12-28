///|
priv struct Line {
  number : Int
  indent : Int
  content : String
}

///|
fn parse_block_document(input : String) -> Yaml raise ParseError {
  let lines = collect_lines(input)
  if lines.length() == 0 {
    return Yaml::Null
  }
  let first = lines[0]
  let (value, next) = parse_block_node(lines, 0, first.indent)
  if next < lines.length() {
    let line = lines[next]
    raise ParseError::UnexpectedChar(
      pos={ line: line.number, column: line.indent + 1 },
      found='-',
    )
  }
  value
}

///|
fn parse_block_node(
  lines : Array[Line],
  index : Int,
  indent : Int,
) -> (Yaml, Int) raise ParseError {
  if index >= lines.length() {
    let pos = match lines.last() {
      None => { line: 1, column: 1 }
      Some(last) => { line: last.number, column: last.indent + 1 }
    }
    raise ParseError::UnexpectedEof(pos~)
  }
  let line = lines[index]
  if line.indent < indent {
    raise ParseError::InvalidIndent(pos={
      line: line.number,
      column: line.indent + 1,
    })
  }
  if is_seq_line(line, indent) {
    parse_block_seq(lines, index, indent)
  } else if is_map_line(line, indent) {
    parse_block_map(lines, index, indent)
  } else {
    (parse_inline_value(line.content), index + 1)
  }
}

///|
fn parse_block_seq(
  lines : Array[Line],
  index : Int,
  indent : Int,
) -> (Yaml, Int) raise ParseError {
  let items : Array[Yaml] = []
  let mut i = index
  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent != indent || !is_seq_line(line, indent) {
      break
    }
    let rest = line.content
      .view(start_offset=1)
      .to_string()
      .trim_start()
      .to_string()
    if rest is "" {
      if i + 1 >= lines.length() || lines[i + 1].indent <= indent {
        items.push(Yaml::Null)
        i = i + 1
      } else {
        let child_indent = lines[i + 1].indent
        let (value, next) = parse_block_node(lines, i + 1, child_indent)
        items.push(value)
        i = next
      }
    } else if split_key_value_opt(rest) is Some(_) {
      let virtual_line = {
        number: line.number,
        indent: indent + 2,
        content: rest,
      }
      let temp : Array[Line] = [virtual_line]
      for j in (i + 1)..<lines.length() {
        temp.push(lines[j])
      }
      let (value, next) = parse_block_map(temp, 0, indent + 2)
      items.push(value)
      i = i + next
    } else {
      items.push(parse_inline_value(rest))
      i = i + 1
    }
  }
  (Yaml::Seq(items), i)
}

///|
fn parse_block_map(
  lines : Array[Line],
  index : Int,
  indent : Int,
) -> (Yaml, Int) raise ParseError {
  let items : Array[(Yaml, Yaml)] = []
  let mut i = index
  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent != indent || !is_map_line(line, indent) {
      break
    }
    let (key_text, value_text) = split_key_value(line)
    let key = parse_inline_value(key_text)
    let trimmed_value = value_text.trim_start().to_string()
    if trimmed_value is "" {
      if i + 1 >= lines.length() || lines[i + 1].indent <= indent {
        items.push((key, Yaml::Null))
        i = i + 1
      } else {
        let child_indent = lines[i + 1].indent
        let (value, next) = parse_block_node(lines, i + 1, child_indent)
        items.push((key, value))
        i = next
      }
    } else {
      let value = parse_inline_value(trimmed_value)
      items.push((key, value))
      i = i + 1
    }
  }
  (Yaml::Map(items), i)
}

///|
fn parse_inline_value(text : String) -> Yaml raise ParseError {
  let trimmed = text.trim().to_string()
  if trimmed is "" {
    return Yaml::Null
  }
  if trimmed.has_prefix("[") || trimmed.has_prefix("{") {
    let scanner = Scanner::new(trimmed)
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(scanner)
    scanner.skip_ws_and_comments()
    match scanner.peek() {
      None => value
      Some(c) =>
        raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
    }
  } else if trimmed.has_prefix("\"") || trimmed.has_prefix("\'") {
    let scanner = Scanner::new(trimmed)
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(scanner)
    scanner.skip_ws_and_comments()
    value
  } else {
    parse_scalar_value(trimmed)
  }
}

///|
fn is_seq_line(line : Line, indent : Int) -> Bool {
  if line.indent != indent {
    return false
  }
  line.content is "-" || line.content.has_prefix("- ")
}

///|
fn is_map_line(line : Line, indent : Int) -> Bool {
  if line.indent != indent {
    return false
  }
  split_key_value_opt(line.content) is Some(_)
}

///|
fn split_key_value(line : Line) -> (String, String) raise ParseError {
  match split_key_value_opt(line.content) {
    None =>
      raise ParseError::UnexpectedChar(
        pos={ line: line.number, column: line.indent + 1 },
        found=':',
      )
    Some(pair) => pair
  }
}

///|
fn split_key_value_opt(content : String) -> (String, String)? {
  let chars = content.to_array()
  let mut in_single = false
  let mut in_double = false
  let mut i = 0
  let mut found = false
  let key_sb = StringBuilder::new()
  let mut value_start = 0
  while i < chars.length() {
    let c = chars[i]
    if in_single {
      if c is '\'' {
        in_single = false
      }
      key_sb.write_char(c)
      i = i + 1
      continue
    }
    if in_double {
      if c is '"' {
        in_double = false
        key_sb.write_char(c)
        i = i + 1
        continue
      }
      if c is '\\' && i + 1 < chars.length() {
        key_sb.write_char(c)
        key_sb.write_char(chars[i + 1])
        i = i + 2
        continue
      }
      key_sb.write_char(c)
      i = i + 1
      continue
    }
    if c is '\'' {
      in_single = true
      key_sb.write_char(c)
      i = i + 1
      continue
    }
    if c is '"' {
      in_double = true
      key_sb.write_char(c)
      i = i + 1
      continue
    }
    if c is ':' {
      if i + 1 == chars.length() || chars[i + 1].is_whitespace() {
        found = true
        value_start = i + 1
        break
      }
    }
    key_sb.write_char(c)
    i = i + 1
  }
  if !found {
    return None
  }
  let key = key_sb.to_string().trim().to_string()
  let value_sb = StringBuilder::new()
  for j in value_start..<chars.length() {
    value_sb.write_char(chars[j])
  }
  Some((key, value_sb.to_string()))
}

///|
fn collect_lines(input : String) -> Array[Line] raise ParseError {
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let lines : Array[Line] = []
  let mut number = 1
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    let mut indent = 0
    let chars = line.to_array()
    while indent < chars.length() {
      let c = chars[indent]
      if c is ' ' {
        indent = indent + 1
      } else if c is '\t' {
        raise ParseError::InvalidIndent(pos={ line: number, column: indent + 1 })
      } else {
        break
      }
    }
    let content = line.view(start_offset=indent).to_string()
    let stripped = strip_inline_comment(content)
    let trimmed = stripped.trim_end().to_string()
    if trimmed is "" {
      number = number + 1
      continue
    }
    lines.push({ number, indent, content: trimmed })
    number = number + 1
  }
  lines
}

///|
fn strip_inline_comment(line : String) -> String {
  let chars = line.to_array()
  let mut i = 0
  let mut in_single = false
  let mut in_double = false
  let mut prev_space = true
  let sb = StringBuilder::new()
  while i < chars.length() {
    let c = chars[i]
    if in_single {
      if c is '\'' {
        in_single = false
      }
      sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if in_double {
      if c is '"' {
        in_double = false
        sb.write_char(c)
        prev_space = false
        i = i + 1
        continue
      }
      if c is '\\' && i + 1 < chars.length() {
        sb.write_char(c)
        sb.write_char(chars[i + 1])
        prev_space = false
        i = i + 2
        continue
      }
      sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '\'' {
      in_single = true
      sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '"' {
      in_double = true
      sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '#' && prev_space {
      break
    }
    sb.write_char(c)
    prev_space = c.is_whitespace()
    i = i + 1
  }
  sb.to_string()
}
