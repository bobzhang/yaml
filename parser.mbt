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
  if trimmed.has_prefix("[") || trimmed.has_prefix("{") {
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
  if trimmed.has_prefix("[") || trimmed.has_prefix("{") {
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
  let ctx =
    if coerce_binary {
      TagContext::new()
    } else {
      TagContext::new_raw()
    }
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let sb = StringBuilder::new()
  let mut in_directives = true
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
    sb.write_string(line)
    sb.write_char('\n')
  }
  (ctx, sb.to_string())
}

///|
fn parse_directive(ctx : TagContext, line : String) -> Unit raise ParseError {
  let parts = split_ws(line)
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
    if parts.length() < 2 {
      raise ParseError::InvalidDirective(
        detail="YAML directive expects version",
      )
    }
    let version = parts[1]
    if version != "1.2" {
      raise ParseError::InvalidDirective(detail="unsupported YAML version")
    }
  } else {
    // Ignore unknown or reserved directives per YAML 1.2.
    ()
  }
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
fn split_documents(input : String) -> Array[String] {
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let docs : Array[String] = []
  let sb = StringBuilder::new()
  let mut has_content = false
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    match doc_start_rest(line) {
      Some(rest) => {
        if has_content && !sb.is_empty() {
          docs.push(sb.to_string())
          sb.reset()
        }
        has_content = false
        if rest != "" {
          sb.write_string(rest)
          sb.write_char('\n')
          has_content = true
        }
        continue
      }
      None => ()
    }
    if is_doc_end_marker(line) {
      if has_content && !sb.is_empty() {
        docs.push(sb.to_string())
        sb.reset()
      }
      has_content = false
      continue
    }
    sb.write_string(line)
    sb.write_char('\n')
    if !has_content && !is_non_content_line(line) {
      has_content = true
    }
  }
  if !sb.is_empty() || docs.length() == 0 {
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
