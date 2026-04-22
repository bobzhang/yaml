///|
pub fn parse_yaml_stream(input : String) -> Array[Yaml] raise ParseError {
  let normalized = strip_bom(input)
  split_documents(normalized).map(doc => parse_document(doc))
}

///|
pub fn parse_yaml_stream_raw(input : String) -> Array[Yaml] raise ParseError {
  let normalized = strip_bom(input)
  split_documents(normalized).map(doc => parse_document_raw(doc))
}

///|
pub fn parse_yaml(input : String) -> Yaml raise ParseError {
  let docs = parse_yaml_stream(input)
  if docs.length() == 0 {
    Yaml::Null
  } else if docs.length() == 1 {
    docs[0]
  } else {
    raise ParseError::MultipleDocuments(count=docs.length())
  }
}

///|
fn parse_document(input : String) -> Yaml raise ParseError {
  let (ctx, content) = extract_directives(input, true)
  let trimmed = content.trim().to_string()
  if trimmed is "" {
    return Yaml::Null
  }
  if is_flow_document(content) {
    let scanner = Scanner::new(content)
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(ctx, scanner)
    scanner.skip_ws_and_comments()
    match scanner.peek() {
      None => resolve_aliases(value)
      Some(c) =>
        raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
    }
  } else {
    resolve_aliases(parse_block_document(ctx, content))
  }
}

///|
fn parse_document_raw(input : String) -> Yaml raise ParseError {
  let (ctx, content) = extract_directives(input, false)
  let trimmed = content.trim().to_string()
  if trimmed is "" {
    return Yaml::Null
  }
  if is_flow_document(content) {
    let scanner = Scanner::new(content)
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(ctx, scanner)
    scanner.skip_ws_and_comments()
    match scanner.peek() {
      None => value
      Some(c) =>
        raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
    }
  } else {
    parse_block_document(ctx, content)
  }
}

///|
fn strip_bom(input : String) -> String {
  if input.has_prefix("\u{feff}") {
    input.view(start_offset=1).to_string()
  } else {
    input
  }
}

///|
fn extract_directives(
  input : String,
  coerce_binary : Bool,
) -> (TagContext, String) raise ParseError {
  let ctx = if coerce_binary {
    TagContext::new()
  } else {
    TagContext::new_raw()
  }
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let sb = StringBuilder::new()
  let mut in_directives = true
  let mut wrote_line = false
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    let trimmed = line.trim().to_string()
    if in_directives {
      if trimmed is "" || trimmed.has_prefix("#") {
        continue
      }
      if trimmed.has_prefix("%") {
        parse_directive(ctx, trimmed)
        continue
      }
      in_directives = false
    }
    if wrote_line {
      sb.write_char('\n')
    }
    sb.write_string(line)
    wrote_line = true
  }
  (ctx, sb.to_string())
}

///|
fn parse_directive(ctx : TagContext, line : String) -> Unit raise ParseError {
  let parts = split_ws(strip_inline_comment(line))
  if parts.length() == 0 {
    return
  }
  let name = parts[0]
  if name is "%TAG" {
    if parts.length() != 3 {
      raise ParseError::InvalidDirective(detail="TAG directive expects 2 args")
    }
    let handle = parts[1]
    let prefix = parts[2]
    ctx.set_handle(handle, prefix)
  } else if name is "%YAML" {
    if parts.length() != 2 {
      raise ParseError::InvalidDirective(
        detail="YAML directive expects version",
      )
    }
    if ctx.seen_yaml {
      raise ParseError::InvalidDirective(detail="duplicate YAML directive")
    }
    ctx.seen_yaml = true
    let version = parts[1]
    if !is_valid_yaml_version(version) {
      raise ParseError::InvalidDirective(detail="unsupported YAML version")
    }
  } else {
    // Ignore unknown or reserved directives per YAML 1.2.
    ()
  }
}

///|
fn is_valid_yaml_version(version : String) -> Bool {
  if !version.has_prefix("1.") {
    return false
  }
  let chars = version.to_array()
  let mut i = 2
  let mut saw_digit = false
  let mut prev_dot = false
  while i < chars.length() {
    let c = chars[i]
    if c.is_ascii_digit() {
      saw_digit = true
      prev_dot = false
    } else if c is '.' {
      if prev_dot {
        return false
      }
      prev_dot = true
    } else {
      return false
    }
    i = i + 1
  }
  saw_digit && !prev_dot
}

///|
fn split_ws(line : String) -> Array[String] {
  let parts : Array[String] = []
  let sb = StringBuilder::new()
  let mut in_token = false
  for c in line {
    if c.is_whitespace() {
      if in_token {
        parts.push(sb.to_string())
        sb.reset()
        in_token = false
      }
    } else {
      sb.write_char(c)
      in_token = true
    }
  }
  if in_token {
    parts.push(sb.to_string())
  }
  parts
}

///|
fn split_documents(input : String) -> Array[String] raise ParseError {
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let docs : Array[String] = []
  let sb = StringBuilder::new()
  let mut in_doc = false
  let mut in_directives = false
  let mut saw_directive = false
  let mut explicit_start = false
  let mut content_seen = false
  let mut wrote_line = false
  fn append_line(line : String) -> Unit {
    if wrote_line {
      sb.write_char('\n')
    }
    sb.write_string(line)
    wrote_line = true
  }
  fn validate_directives(
    saw_directive : Bool,
    explicit_start : Bool,
    content_seen : Bool,
  ) -> Unit raise ParseError {
    if saw_directive && !explicit_start {
      if content_seen {
        raise ParseError::InvalidDirective(
          detail="directive without document start",
        )
      } else {
        raise ParseError::InvalidDirective(detail="directive without document")
      }
    }
  }
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    match doc_start_rest(line) {
      Some(rest) => {
        if in_doc {
          if !(in_directives && !content_seen) {
            validate_directives(saw_directive, explicit_start, content_seen)
            docs.push(sb.to_string())
            sb.reset()
            wrote_line = false
            saw_directive = false
          }
        }
        in_doc = true
        in_directives = false
        explicit_start = true
        content_seen = false
        if rest != "" {
          if split_key_value_opt(rest) is Some(_) {
            raise ParseError::InvalidDirective(
              detail="mapping on document start line",
            )
          }
          append_line(rest)
          if !is_non_content_line(rest) {
            content_seen = true
          }
        }
        continue
      }
      None => ()
    }
    if is_doc_end_marker(line) {
      if in_doc || wrote_line {
        validate_directives(saw_directive, explicit_start, content_seen)
        docs.push(sb.to_string())
        sb.reset()
        wrote_line = false
      }
      in_doc = false
      in_directives = false
      saw_directive = false
      explicit_start = false
      content_seen = false
      continue
    }
    let trimmed = line.trim().to_string()
    if !in_doc {
      if trimmed is "" || trimmed.has_prefix("#") {
        continue
      }
      if trimmed.has_prefix("%") {
        in_doc = true
        in_directives = true
        saw_directive = true
        append_line(line)
        continue
      }
      in_doc = true
      in_directives = false
      explicit_start = false
      if !is_non_content_line(line) {
        content_seen = true
      }
      append_line(line)
      continue
    }
    if in_directives {
      if trimmed is "" || trimmed.has_prefix("#") {
        continue
      }
      if trimmed.has_prefix("%") {
        saw_directive = true
        append_line(line)
        continue
      }
      validate_directives(saw_directive, explicit_start, content_seen)
      in_directives = false
      if !is_non_content_line(line) {
        content_seen = true
      }
      append_line(line)
      continue
    }
    if !is_non_content_line(line) {
      content_seen = true
    }
    append_line(line)
  }
  if in_doc || wrote_line {
    validate_directives(saw_directive, explicit_start, content_seen)
    docs.push(sb.to_string())
  }
  docs
}

///|
fn doc_start_rest(line : String) -> String? {
  let mut indent = 0
  let chars = line.to_array()
  while indent < chars.length() &&
        (chars[indent] is ' ' || chars[indent] is '\t') {
    indent = indent + 1
  }
  if indent > 0 {
    return None
  }
  let stripped = strip_inline_comment(line).trim().to_string()
  if stripped.has_prefix("---") {
    if stripped.length() == 3 {
      return Some("")
    }
    let next = stripped.get_char(3)
    match next {
      Some(c) if c.is_whitespace() =>
        Some(stripped.view(start_offset=3).trim_start().to_string())
      _ => None
    }
  } else {
    None
  }
}

///|
fn is_flow_document(text : String) -> Bool {
  let trimmed = text.trim_start().to_string()
  if !(trimmed.has_prefix("[") || trimmed.has_prefix("{")) {
    return false
  }
  let chars = trimmed.to_array()
  let mut depth = 0
  let mut in_single = false
  let mut in_double = false
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if in_double {
      if c is '\\' && i + 1 < chars.length() {
        i = i + 2
        continue
      }
      if c is '"' {
        in_double = false
      }
      i = i + 1
      continue
    }
    if in_single {
      if c is '\'' {
        in_single = false
      }
      i = i + 1
      continue
    }
    if c is '"' {
      in_double = true
      i = i + 1
      continue
    }
    if c is '\'' {
      in_single = true
      i = i + 1
      continue
    }
    if c is '[' || c is '{' {
      depth = depth + 1
    } else if c is ']' || c is '}' {
      if depth > 0 {
        depth = depth - 1
      }
      if depth == 0 {
        let rest = trimmed.view(start_offset=i + 1).to_string()
        let rest_trimmed = strip_inline_comment(rest).trim().to_string()
        return rest_trimmed is ""
      }
    }
    i = i + 1
  }
  false
}

///|
fn is_doc_end_marker(line : String) -> Bool {
  let mut indent = 0
  let chars = line.to_array()
  while indent < chars.length() &&
        (chars[indent] is ' ' || chars[indent] is '\t') {
    indent = indent + 1
  }
  if indent > 0 {
    return false
  }
  let stripped = strip_inline_comment(line).trim().to_string()
  stripped is "..."
}

///|
fn is_non_content_line(line : String) -> Bool {
  let stripped = strip_inline_comment(line).trim().to_string()
  stripped is "" || stripped.has_prefix("#") || stripped.has_prefix("%")
}
