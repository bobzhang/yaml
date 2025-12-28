///|
pub fn parse_yaml_stream(input : String) -> Array[Yaml] raise ParseError {
  split_documents(input).map(doc => parse_document(doc))
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
  let trimmed = input.trim().to_string()
  if trimmed is "" {
    return Yaml::Null
  }
  if trimmed.has_prefix("[") || trimmed.has_prefix("{") {
    let scanner = Scanner::new(input)
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(scanner)
    scanner.skip_ws_and_comments()
    match scanner.peek() {
      None => resolve_aliases(value)
      Some(c) =>
        raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
    }
  } else {
    resolve_aliases(parse_block_document(input))
  }
}

///|
fn split_documents(input : String) -> Array[String] {
  let normalized = input
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let docs : Array[String] = []
  let sb = StringBuilder::new()
  for line_view in normalized.split("\n") {
    let line = line_view.to_string()
    if is_doc_marker(line) {
      if !sb.is_empty() {
        docs.push(sb.to_string())
        sb.reset()
      }
      continue
    }
    sb.write_string(line)
    sb.write_char('\n')
  }
  if !sb.is_empty() || docs.length() == 0 {
    docs.push(sb.to_string())
  }
  docs
}

///|
fn is_doc_marker(line : String) -> Bool {
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
  stripped is "---" || stripped is "..."
}
