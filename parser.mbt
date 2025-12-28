///|
pub fn parse_yaml(input : String) -> Yaml raise ParseError {
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
