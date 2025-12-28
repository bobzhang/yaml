///|
priv struct Line {
  number : Int
  indent : Int
  raw : String
  content : String
}

///|
priv enum Chomp {
  Clip
  Strip
  Keep
}

///|
fn parse_block_document(input : String) -> Yaml raise ParseError {
  let lines = collect_lines(input)
  let start = next_non_empty(lines, 0)
  if start >= lines.length() {
    return Yaml::Null
  }
  let first = lines[start]
  let (value, next) = parse_block_node(lines, start, first.indent)
  let rest = next_non_empty(lines, next)
  if rest < lines.length() {
    let line = lines[rest]
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
  let start = next_non_empty(lines, index)
  if start >= lines.length() {
    let pos = match lines.last() {
      None => { line: 1, column: 1 }
      Some(last) => { line: last.number, column: last.indent + 1 }
    }
    raise ParseError::UnexpectedEof(pos~)
  }
  let line = lines[start]
  if line.indent < indent {
    raise ParseError::InvalidIndent(pos={
      line: line.number,
      column: line.indent + 1,
    })
  }
  if is_seq_line(line, indent) {
    parse_block_seq(lines, start, indent)
  } else if is_map_line(line, indent) {
    parse_block_map(lines, start, indent)
  } else {
    (parse_inline_value(line.content), start + 1)
  }
}

///|
fn next_non_empty(lines : Array[Line], index : Int) -> Int {
  let mut i = index
  while i < lines.length() && lines[i].content is "" {
    i = i + 1
  }
  i
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
    i = next_non_empty(lines, i)
    if i >= lines.length() {
      break
    }
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
      let next_index = next_non_empty(lines, i + 1)
      if next_index >= lines.length() || lines[next_index].indent <= indent {
        items.push(Yaml::Null)
        i = next_index
      } else {
        let child_indent = lines[next_index].indent
        let (value, next) = parse_block_node(lines, next_index, child_indent)
        items.push(value)
        i = next
      }
    } else {
      match try_parse_block_scalar(rest, lines, i + 1, indent) {
        Some((node, next)) => {
          items.push(node)
          i = next
        }
        None =>
          if split_key_value_opt(rest) is Some(_) {
            let virtual_line = {
              number: line.number,
              indent: indent + 2,
              raw: rest,
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
    i = next_non_empty(lines, i)
    if i >= lines.length() {
      break
    }
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
      let next_index = next_non_empty(lines, i + 1)
      if next_index >= lines.length() {
        items.push((key, Yaml::Null))
        i = next_index
      } else if lines[next_index].indent > indent {
        let child_indent = lines[next_index].indent
        let (value, next) = parse_block_node(lines, next_index, child_indent)
        items.push((key, value))
        i = next
      } else if is_seq_line(lines[next_index], indent) {
        let (value, next) = parse_block_seq(lines, next_index, indent)
        items.push((key, value))
        i = next
      } else {
        items.push((key, Yaml::Null))
        i = next_index
      }
    } else {
      match try_parse_block_scalar(trimmed_value, lines, i + 1, indent) {
        Some((node, next)) => {
          items.push((key, node))
          i = next
        }
        None => {
          let value = parse_inline_value(trimmed_value)
          items.push((key, value))
          i = i + 1
        }
      }
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
  let scanner = Scanner::new(trimmed)
  scanner.skip_ws_and_comments()
  match parse_alias(scanner) {
    Some(name) => Yaml::Alias(name)
    None => {
      let (tag, anchor) = parse_node_props(scanner)
      scanner.skip_ws_and_comments()
      let rest = trimmed
        .view(start_offset=scanner.offset())
        .to_string()
        .trim_start()
        .to_string()
      let value = if rest is "" {
        Yaml::Null
      } else if rest.has_prefix("[") || rest.has_prefix("{") {
        parse_flow_value_from_string(rest)
      } else if rest.has_prefix("\"") || rest.has_prefix("'") {
        parse_flow_value_from_string(rest)
      } else {
        parse_scalar_value(rest)
      }
      apply_node_props(value, tag, anchor)
    }
  }
}

///|
fn parse_block_indicator(text : String) -> (Char, Chomp)? {
  let trimmed = text.trim().to_string()
  if trimmed is "" {
    return None
  }
  let chars = trimmed.to_array()
  let style = chars[0]
  if !(style is '|' || style is '>') {
    return None
  }
  if chars.length() == 1 {
    return Some((style, Chomp::Clip))
  }
  let modifier = chars[1]
  if modifier is '+' {
    Some((style, Chomp::Keep))
  } else if modifier is '-' {
    Some((style, Chomp::Strip))
  } else {
    None
  }
}

///|
fn try_parse_block_scalar(
  rest : String,
  lines : Array[Line],
  index : Int,
  parent_indent : Int,
) -> (Yaml, Int)? raise ParseError {
  let scanner = Scanner::new(rest)
  scanner.skip_ws_and_comments()
  if parse_alias(scanner) is Some(_) {
    return None
  }
  let (tag, anchor) = parse_node_props(scanner)
  scanner.skip_ws_and_comments()
  let tail = rest
    .view(start_offset=scanner.offset())
    .to_string()
    .trim_start()
    .to_string()
  match parse_block_indicator(tail) {
    None => None
    Some((style, chomp)) => {
      let (value, next) = parse_block_scalar(
        lines, index, parent_indent, style, chomp,
      )
      Some((apply_node_props(Yaml::String(value), tag, anchor), next))
    }
  }
}

///|
fn parse_block_scalar(
  lines : Array[Line],
  index : Int,
  parent_indent : Int,
  style : Char,
  chomp : Chomp,
) -> (String, Int) {
  let mut i = index
  let mut content_indent : Int? = None
  let collected : Array[String] = []
  let mut pending_blank = 0
  while i < lines.length() {
    let line = lines[i]
    let raw_content = line.raw.view(start_offset=line.indent).to_string()
    if raw_content.trim() is "" {
      pending_blank = pending_blank + 1
      i = i + 1
      continue
    }
    if line.indent <= parent_indent {
      break
    }
    if content_indent is None {
      content_indent = Some(line.indent)
    }
    let indent = content_indent.unwrap_or(line.indent)
    if line.indent < indent {
      break
    }
    for _ in 0..<pending_blank {
      collected.push("")
    }
    pending_blank = 0
    let raw = line.raw
    let text = raw.view(start_offset=indent).to_string()
    collected.push(text)
    i = i + 1
  }
  for _ in 0..<pending_blank {
    collected.push("")
  }
  let base = if style is '|' {
    join_lines(collected)
  } else {
    fold_lines(collected)
  }
  let with_newline = if collected.length() > 0 { base + "\n" } else { "" }
  let value = apply_chomp(with_newline, chomp)
  (value, i)
}

///|
fn join_lines(lines : Array[String]) -> String {
  let sb = StringBuilder::new()
  for idx in 0..<lines.length() {
    if idx > 0 {
      sb.write_char('\n')
    }
    sb.write_string(lines[idx])
  }
  sb.to_string()
}

///|
fn fold_lines(lines : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut prev_blank = false
  for idx in 0..<lines.length() {
    let line = lines[idx]
    let is_blank = line is ""
    if idx > 0 {
      if is_blank || prev_blank {
        sb.write_char('\n')
      } else {
        sb.write_char(' ')
      }
    }
    sb.write_string(line)
    prev_blank = is_blank
  }
  sb.to_string()
}

///|
fn apply_chomp(text : String, chomp : Chomp) -> String {
  match chomp {
    Chomp::Clip => {
      let trimmed = trim_trailing_newlines(text)
      if trimmed is "" {
        ""
      } else {
        trimmed + "\n"
      }
    }
    Chomp::Strip => trim_trailing_newlines(text)
    Chomp::Keep => text
  }
}

///|
fn trim_trailing_newlines(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] is '\n' {
    end = end - 1
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
    lines.push({ number, indent, raw: line, content: trimmed })
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
