///|
pub fn parse_yaml(input : String) -> Yaml raise ParseError {
  let scanner = Scanner::new(input)
  scanner.skip_ws_and_comments()
  let value = parse_flow_node(scanner)
  scanner.skip_ws_and_comments()
  match scanner.peek() {
    None => value
    Some(c) => raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
  }
}
