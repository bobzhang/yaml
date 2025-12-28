///|
priv struct Line {
  number : Int
  indent : Int
  has_tab_indent : Bool
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
fn parse_block_document(
  ctx : TagContext,
  input : String,
) -> Yaml raise ParseError {
  let lines = collect_lines(input)
  let start = next_non_empty(lines, 0)
  if start >= lines.length() {
    return Yaml::Null
  }
  let first = lines[start]
  let (value, next) =
    parse_block_node(ctx, lines, start, first.indent, true)
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
  ctx : TagContext,
  lines : Array[Line],
  index : Int,
  indent : Int,
  allow_same_indent_props : Bool,
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
  if line.has_tab_indent {
    raise ParseError::InvalidIndent(pos={
      line: line.number,
      column: line.indent + 1,
    })
  }
  if line.indent < indent {
    raise ParseError::InvalidIndent(pos={
      line: line.number,
      column: line.indent + 1,
    })
  }
  if is_seq_line(line, indent) {
    parse_block_seq(ctx, lines, start, indent)
  } else if is_map_start(lines, start, indent) {
    parse_block_map(ctx, lines, start, indent)
  } else {
    parse_value_from_text(
      ctx,
      lines,
      start,
      indent,
      line.content,
      allow_same_indent_props,
    )
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
  ctx : TagContext,
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
    if line.has_tab_indent {
      raise ParseError::InvalidIndent(pos={
        line: line.number,
        column: line.indent + 1,
      })
    }
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
        let (value, next) =
          parse_block_node(ctx, lines, next_index, child_indent, true)
        items.push(value)
        i = next
      }
    } else {
      match try_parse_block_scalar(ctx, rest, lines, i + 1, indent) {
        Some((node, next)) => {
          items.push(node)
          i = next
        }
        None =>
          if rest is "-" || rest.has_prefix("- ") {
            let virtual_line = {
              number: line.number,
              indent: indent + 2,
              has_tab_indent: false,
              raw: rest,
              content: rest,
            }
            let temp : Array[Line] = [virtual_line]
            for j in (i + 1)..<lines.length() {
              temp.push(lines[j])
            }
            let (value, next) = parse_block_seq(ctx, temp, 0, indent + 2)
            items.push(value)
            i = i + next
          } else if split_key_value_opt(rest) is Some(_) {
            let virtual_line = {
              number: line.number,
              indent: indent + 2,
              has_tab_indent: false,
              raw: rest,
              content: rest,
            }
            let temp : Array[Line] = [virtual_line]
            for j in (i + 1)..<lines.length() {
              temp.push(lines[j])
            }
            let (value, next) = parse_block_map(ctx, temp, 0, indent + 2)
            items.push(value)
            i = i + next
          } else {
            let (value, next) =
              parse_value_from_text(ctx, lines, i, indent, rest, false)
            items.push(value)
            i = next
          }
      }
    }
  }
  (Yaml::Seq(items), i)
}

///|
fn parse_block_map(
  ctx : TagContext,
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
    if line.has_tab_indent {
      raise ParseError::InvalidIndent(pos={
        line: line.number,
        column: line.indent + 1,
      })
    }
    if line.indent < indent {
      break
    }
    if line.indent != indent {
      break
    }
    if is_explicit_key_line(line, indent) {
      let (entry, next) = parse_explicit_entry(ctx, lines, i, indent)
      items.push(entry)
      i = next
    } else if split_key_value_opt(line.content) is Some(_) {
      let (key_text, value_text) = split_key_value(line)
      let key = parse_inline_key(ctx, key_text)
      let (value, next) =
        parse_value_from_text(ctx, lines, i, indent, value_text, false)
      items.push((key, value))
      i = next
    } else if is_value_line_after(lines, i, indent) {
      let key = parse_inline_key(ctx, line.content)
      let value_line = next_non_empty(lines, i + 1)
      let value_text = lines[value_line].content
        .view(start_offset=1)
        .to_string()
      let (value, next) =
        parse_value_from_text(ctx, lines, value_line, indent, value_text, false)
      items.push((key, value))
      i = next
    } else if !is_map_line(line, indent) {
      break
    }
  }
  (Yaml::Map(items), i)
}

///|
fn parse_inline_value(ctx : TagContext, text : String) -> Yaml raise ParseError {
  let trimmed = text.trim().to_string()
  if trimmed is "" {
    return Yaml::Null
  }
  let scanner = Scanner::new(trimmed)
  scanner.skip_ws_and_comments()
  match parse_alias(scanner) {
    Some(name) => Yaml::Alias(name)
    None => {
      let (tag, anchor) = parse_node_props(ctx, scanner)
      scanner.skip_ws_and_comments()
      let rest = trimmed
        .view(start_offset=scanner.offset())
        .to_string()
        .trim_start()
        .to_string()
      let value = if rest is "" {
        Yaml::Null
      } else if rest.has_prefix("[") || rest.has_prefix("{") {
        parse_flow_value_from_string(ctx, rest)
      } else if rest.has_prefix("\"") || rest.has_prefix("'") {
        parse_flow_value_from_string(ctx, rest)
      } else if tag is Some(_) {
        Yaml::String(rest)
      } else {
        parse_scalar_value(rest)
      }
      apply_node_props(value, tag, anchor, ctx.coerce_binary)
    }
  }
}

///|
fn parse_inline_key(ctx : TagContext, text : String) -> Yaml raise ParseError {
  let trimmed = text.trim().to_string()
  if trimmed is "" {
    Yaml::String("")
  } else {
    parse_inline_value(ctx, text)
  }
}

///|
fn parse_value_from_text(
  ctx : TagContext,
  lines : Array[Line],
  line_index : Int,
  indent : Int,
  value_text : String,
  allow_same_indent_props : Bool,
) -> (Yaml, Int) raise ParseError {
  let trimmed_value = value_text.trim_start().to_string()
  if trimmed_value is "" {
    let next_index = next_non_empty(lines, line_index + 1)
    if next_index >= lines.length() {
      (Yaml::Null, next_index)
    } else if lines[next_index].indent > indent {
      let child_indent = lines[next_index].indent
      parse_block_node(ctx, lines, next_index, child_indent, true)
    } else if is_seq_line(lines[next_index], indent) {
      parse_block_seq(ctx, lines, next_index, indent)
    } else {
      (Yaml::Null, next_index)
    }
  } else {
    if trimmed_value.has_prefix("\"") && !is_terminated_double(trimmed_value) {
      let (combined, next) =
        collect_quoted_multiline(lines, line_index, '"', trimmed_value)
      return (parse_inline_value(ctx, combined), next)
    }
    if trimmed_value.has_prefix("'") && !is_terminated_single(trimmed_value) {
      let (combined, next) =
        collect_quoted_multiline(lines, line_index, '\'', trimmed_value)
      return (parse_inline_value(ctx, combined), next)
    }
    match try_parse_quoted_props(ctx, trimmed_value, lines, line_index) {
      Some((node, next)) => return (node, next)
      None => ()
    }
    match
      try_parse_props_only(
        ctx,
        trimmed_value,
        lines,
        line_index,
        indent,
        allow_same_indent_props,
      ) {
      Some((node, next)) => return (node, next)
      None => ()
    }
    match
      try_parse_block_scalar(ctx, trimmed_value, lines, line_index + 1, indent) {
      Some((node, next)) => (node, next)
      None => {
        let value = parse_inline_value(ctx, trimmed_value)
        if value is String(_) && is_plain_scalar_start(trimmed_value) {
          let (parts, next) = collect_plain_continuation(
            lines,
            line_index + 1,
            indent,
            allow_same_indent_props,
          )
          if parts.length() > 0 {
            let joined = fold_plain_lines(trimmed_value, parts)
            (Yaml::String(joined), next)
          } else {
            (value, line_index + 1)
          }
        } else {
          (value, line_index + 1)
        }
      }
    }
  }
}

///|
fn try_parse_props_only(
  ctx : TagContext,
  text : String,
  lines : Array[Line],
  line_index : Int,
  indent : Int,
  allow_same_indent_props : Bool,
) -> (Yaml, Int)? raise ParseError {
  let scanner = Scanner::new(text)
  scanner.skip_ws_and_comments()
  if parse_alias(scanner) is Some(_) {
    return None
  }
  let (tag, anchor) = parse_node_props(ctx, scanner)
  scanner.skip_ws_and_comments()
  let rest = text
    .view(start_offset=scanner.offset())
    .to_string()
    .trim_start()
    .to_string()
  if rest is "" && (tag is Some(_) || anchor is Some(_)) {
    let next_index = next_non_empty(lines, line_index + 1)
    if next_index < lines.length() {
      let next_line = lines[next_index]
      if next_line.indent > indent {
        let child_indent = next_line.indent
        let (value, next) =
          parse_block_node(ctx, lines, next_index, child_indent, true)
        return Some((apply_node_props(value, tag, anchor, ctx.coerce_binary), next))
      }
      if allow_same_indent_props && next_line.indent == indent {
        let (value, next) =
          parse_block_node(ctx, lines, next_index, indent, true)
        return Some((apply_node_props(value, tag, anchor, ctx.coerce_binary), next))
      }
    }
    return Some((apply_node_props(Yaml::Null, tag, anchor, ctx.coerce_binary), line_index + 1))
  }
  None
}

///|
fn try_parse_quoted_props(
  ctx : TagContext,
  text : String,
  lines : Array[Line],
  line_index : Int,
) -> (Yaml, Int)? raise ParseError {
  let scanner = Scanner::new(text)
  scanner.skip_ws_and_comments()
  if parse_alias(scanner) is Some(_) {
    return None
  }
  let (tag, anchor) = parse_node_props(ctx, scanner)
  scanner.skip_ws_and_comments()
  let rest = text
    .view(start_offset=scanner.offset())
    .to_string()
    .trim_start()
    .to_string()
  if rest.has_prefix("\"") && !is_terminated_double(rest) {
    let (combined, next) = collect_quoted_multiline(
      lines,
      line_index,
      '"',
      rest,
    )
    let value = parse_flow_value_from_string(ctx, combined)
    return Some((apply_node_props(value, tag, anchor, ctx.coerce_binary), next))
  }
  if rest.has_prefix("'") && !is_terminated_single(rest) {
    let (combined, next) = collect_quoted_multiline(
      lines,
      line_index,
      '\'',
      rest,
    )
    let value = parse_flow_value_from_string(ctx, combined)
    return Some((apply_node_props(value, tag, anchor, ctx.coerce_binary), next))
  }
  None
}

///|
fn collect_quoted_multiline(
  lines : Array[Line],
  index : Int,
  quote : Char,
  first : String,
) -> (String, Int) raise ParseError {
  let mut combined = first.trim_end().to_string()
  let mut i = index + 1
  while i < lines.length() {
    let raw = lines[i].raw.view(start_offset=lines[i].indent).to_string()
    combined = combined + "\n" + raw
    if quote is '"' {
      if is_terminated_double(combined) {
        return (combined, i + 1)
      }
    } else if is_terminated_single(combined) {
      return (combined, i + 1)
    }
    i = i + 1
  }
  raise ParseError::UnexpectedEof(pos={
    line: match lines.last() {
      None => 1
      Some(last) => last.number
    },
    column: 1,
  })
}

///|
fn is_terminated_double(text : String) -> Bool {
  let chars = text.to_array()
  let mut escaped = false
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if i == 0 && c is '"' {
      i = i + 1
      continue
    }
    if escaped {
      escaped = false
      i = i + 1
      continue
    }
    if c is '\\' {
      escaped = true
      i = i + 1
      continue
    }
    if c is '"' {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn is_terminated_single(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if i == 0 && c is '\'' {
      i = i + 1
      continue
    }
    if c is '\'' {
      if i + 1 < chars.length() && chars[i + 1] is '\'' {
        i = i + 2
        continue
      } else {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn parse_explicit_entry(
  ctx : TagContext,
  lines : Array[Line],
  index : Int,
  indent : Int,
) -> ((Yaml, Yaml), Int) raise ParseError {
  let line = lines[index]
  let rest = line.content
    .view(start_offset=1)
    .to_string()
    .trim_start()
    .to_string()
  if rest is "" {
    let next_index = next_non_empty(lines, index + 1)
    if next_index >= lines.length() || lines[next_index].indent <= indent {
      raise ParseError::InvalidIndent(pos={
        line: line.number,
        column: line.indent + 1,
      })
    }
    let (key, next_after_key) = parse_block_node(
      ctx,
      lines,
      next_index,
      lines[next_index].indent,
      false,
    )
    let value_line = next_non_empty(lines, next_after_key)
    if value_line < lines.length() && is_value_line(lines[value_line], indent) {
      let value_text = lines[value_line].content
        .view(start_offset=1)
        .to_string()
      let (value, next) =
        parse_value_from_text(ctx, lines, value_line, indent, value_text, false)
      ((key, value), next)
    } else {
      ((key, Yaml::String("")), next_after_key)
    }
  } else {
    match split_key_value_opt(rest) {
      Some((key_text, value_text)) => {
        let key = parse_inline_key(ctx, key_text)
        let (value, next) =
          parse_value_from_text(ctx, lines, index, indent, value_text, false)
        ((key, value), next)
      }
      None => {
        let key = parse_inline_key(ctx, rest)
        let value_line = next_non_empty(lines, index + 1)
        if value_line < lines.length() &&
          is_value_line(lines[value_line], indent) {
          let value_text = lines[value_line].content
            .view(start_offset=1)
            .to_string()
          let (value, next) =
            parse_value_from_text(ctx, lines, value_line, indent, value_text, false)
          ((key, value), next)
        } else {
          ((key, Yaml::String("")), index + 1)
        }
      }
    }
  }
}

///|
fn is_plain_scalar_start(text : String) -> Bool {
  if text is "" {
    return false
  }
  let trimmed = text.trim_start().to_string()
  !(trimmed.has_prefix("\"") ||
  trimmed.has_prefix("'") ||
  trimmed.has_prefix("[") ||
  trimmed.has_prefix("{") ||
  trimmed.has_prefix("!") ||
  trimmed.has_prefix("&") ||
  trimmed.has_prefix("*"))
}

///|
fn collect_plain_continuation(
  lines : Array[Line],
  index : Int,
  indent : Int,
  allow_same_indent : Bool,
) -> (Array[String], Int) raise ParseError {
  let parts : Array[String] = []
  let mut i = index
  let mut base_indent : Int? = None
  while i < lines.length() {
    let line = lines[i]
    let raw = line.raw.view(start_offset=line.indent).to_string()
    if raw.trim() is "" {
      let next_index = next_non_empty(lines, i + 1)
      if next_index >= lines.length() {
        break
      }
      if allow_same_indent {
        if lines[next_index].indent < indent {
          break
        }
      } else if lines[next_index].indent <= indent {
        break
      }
      parts.push("")
      i = i + 1
      continue
    }
    if allow_same_indent {
      if line.indent < indent {
        break
      }
    } else if line.indent <= indent {
      break
    }
    if base_indent is None {
      base_indent = Some(line.indent)
    }
    let base = base_indent.unwrap_or(line.indent)
    if line.indent < base {
      break
    }
    let text = line.raw.view(start_offset=base).to_string()
    if has_plain_mapping_break(text) {
      raise ParseError::InvalidIndent(pos={
        line: line.number,
        column: line.indent + 1,
      })
    }
    parts.push(text.trim_end().to_string())
    i = i + 1
  }
  (parts, i)
}

///|
fn has_plain_mapping_break(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c is ':' {
      if i + 1 == chars.length() || chars[i + 1].is_whitespace() {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn fold_plain_lines(first : String, rest : Array[String]) -> String {
  let all : Array[String] = [first]
  for line in rest {
    all.push(line)
  }
  fold_lines(all)
}

///|
fn parse_block_indicator(
  text : String,
  pos : Position,
) -> (Char, Chomp, Int?)? raise ParseError {
  let trimmed = text.trim().to_string()
  if trimmed is "" {
    return None
  }
  let chars = trimmed.to_array()
  let style = chars[0]
  if !(style is '|' || style is '>') {
    return None
  }
  let mut chomp = Chomp::Clip
  let mut indent : Int? = None
  let mut chomp_set = false
  let mut indent_set = false
  let mut i = 1
  while i < chars.length() {
    let c = chars[i]
    if c is '+' {
      if chomp_set {
        raise ParseError::InvalidIndent(pos~)
      }
      chomp = Chomp::Keep
      chomp_set = true
    } else if c is '-' {
      if chomp_set {
        raise ParseError::InvalidIndent(pos~)
      }
      chomp = Chomp::Strip
      chomp_set = true
    } else if c.is_ascii_digit() {
      if indent_set {
        raise ParseError::InvalidIndent(pos~)
      }
      let digit = c.to_int() - '0'.to_int()
      if digit == 0 {
        raise ParseError::InvalidIndent(pos~)
      }
      indent = Some(digit)
      indent_set = true
    } else {
      break
    }
    i = i + 1
  }
  let mut rest = i
  while rest < chars.length() && chars[rest].is_whitespace() {
    rest = rest + 1
  }
  if rest < chars.length() && chars[rest] != '#' {
    raise ParseError::InvalidIndent(pos~)
  }
  Some((style, chomp, indent))
}

///|
fn try_parse_block_scalar(
  ctx : TagContext,
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
  let (tag, anchor) = parse_node_props(ctx, scanner)
  scanner.skip_ws_and_comments()
  let tail = rest
    .view(start_offset=scanner.offset())
    .to_string()
    .trim_start()
    .to_string()
  let pos = { line: lines[index].number, column: lines[index].indent + 1 }
  match parse_block_indicator(tail, pos) {
    None => None
    Some((style, chomp, indent_hint)) => {
      let (value, next) = parse_block_scalar(
        lines, index, parent_indent, style, chomp, indent_hint,
      )
      Some((apply_node_props(Yaml::String(value), tag, anchor, ctx.coerce_binary), next))
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
  indent_hint : Int?,
) -> (String, Int) {
  let mut i = index
  let mut content_indent : Int? = None
  let collected : Array[String] = []
  let mut pending_blank = 0
  while i < lines.length() {
    let line = lines[i]
    let raw_content = line.raw.view(start_offset=line.indent).to_string()
    if raw_content.trim() is "" {
      if content_indent is None && line.indent <= parent_indent {
        break
      }
      pending_blank = pending_blank + 1
      i = i + 1
      continue
    }
    if line.indent <= parent_indent {
      break
    }
    if content_indent is None {
      content_indent = match indent_hint {
        None => Some(line.indent)
        Some(hint) => Some(parent_indent + hint)
      }
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
    fold_block_lines(collected)
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
      if is_blank {
        sb.write_char('\n')
      } else if !prev_blank {
        sb.write_char(' ')
      }
    }
    sb.write_string(line)
    prev_blank = is_blank
  }
  sb.to_string()
}

///|
fn fold_block_lines(lines : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut prev_blank = false
  for idx in 0..<lines.length() {
    let line = lines[idx]
    let is_blank = line is ""
    if idx == 0 {
      if is_blank {
        sb.write_char('\n')
      }
    } else if is_blank {
      sb.write_char('\n')
    } else if !prev_blank {
      sb.write_char(' ')
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
  is_explicit_key_line(line, indent) ||
  split_key_value_opt(line.content) is Some(_)
}

///|
fn is_map_start(lines : Array[Line], index : Int, indent : Int) -> Bool {
  let line = lines[index]
  if line.indent != indent {
    return false
  }
  is_explicit_key_line(line, indent) ||
  split_key_value_opt(line.content) is Some(_) ||
  is_value_line_after(lines, index, indent)
}

///|
fn is_explicit_key_line(line : Line, indent : Int) -> Bool {
  if line.indent != indent {
    return false
  }
  line.content is "?" || line.content.has_prefix("? ")
}

///|
fn is_value_line(line : Line, indent : Int) -> Bool {
  if line.indent != indent {
    return false
  }
  line.content is ":" || line.content.has_prefix(": ")
}

///|
fn is_value_line_after(
  lines : Array[Line],
  index : Int,
  indent : Int,
) -> Bool {
  let next_index = next_non_empty(lines, index + 1)
  if next_index >= lines.length() {
    return false
  }
  is_value_line(lines[next_index], indent)
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
  let mut depth = 0
  let mut i = 0
  let mut found = false
  let key_sb = StringBuilder::new()
  let mut value_start = 0
  let mut prev_space = true
  while i < chars.length() {
    let c = chars[i]
    if prev_space && (c is '&' || c is '!' || c is '*') {
      key_sb.write_char(c)
      i = i + 1
      while i < chars.length() {
        let ch = chars[i]
        if ch.is_whitespace() || ch is ',' || ch is ']' || ch is '}' || ch is '#' {
          break
        }
        key_sb.write_char(ch)
        i = i + 1
      }
      prev_space = false
      continue
    }
    if in_single {
      if c is '\'' {
        in_single = false
      }
      key_sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if in_double {
      if c is '"' {
        in_double = false
        key_sb.write_char(c)
        prev_space = false
        i = i + 1
        continue
      }
      if c is '\\' && i + 1 < chars.length() {
        key_sb.write_char(c)
        key_sb.write_char(chars[i + 1])
        prev_space = false
        i = i + 2
        continue
      }
      key_sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '\'' && prev_space {
      in_single = true
      key_sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '"' && prev_space {
      in_double = true
      key_sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '{' || c is '[' {
      depth = depth + 1
      key_sb.write_char(c)
      prev_space = c.is_whitespace()
      i = i + 1
      continue
    }
    if c is '}' || c is ']' {
      if depth > 0 {
        depth = depth - 1
      }
      key_sb.write_char(c)
      i = i + 1
      continue
    }
    if c is ':' {
      if depth == 0 &&
        (i + 1 == chars.length() || chars[i + 1].is_whitespace()) {
        found = true
        value_start = i + 1
        break
      }
    }
    key_sb.write_char(c)
    prev_space = c.is_whitespace()
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
fn collect_lines(input : String) -> Array[Line] {
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let lines : Array[Line] = []
  let mut number = 1
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    let mut indent = 0
    let mut has_tab_indent = false
    let chars = line.to_array()
    while indent < chars.length() {
      let c = chars[indent]
      if c is ' ' {
        indent = indent + 1
      } else if c is '\t' {
        has_tab_indent = true
        break
      } else {
        break
      }
    }
    let content = line.view(start_offset=indent).to_string()
    let stripped = strip_inline_comment(content)
    let trimmed = stripped.trim_end().to_string()
    lines.push({
      number,
      indent,
      has_tab_indent,
      raw: line,
      content: trimmed,
    })
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
    if c is '\'' && prev_space {
      in_single = true
      sb.write_char(c)
      prev_space = false
      i = i + 1
      continue
    }
    if c is '"' && prev_space {
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
