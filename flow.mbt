///|
fn parse_flow_node(scanner : Scanner) -> Yaml raise ParseError {
  scanner.skip_ws_and_comments()
  match scanner.peek() {
    Some('[') => parse_flow_seq(scanner)
    Some('{') => parse_flow_map(scanner)
    Some('"') => parse_scalar(scanner)
    Some('\'') => parse_scalar(scanner)
    Some(_) => parse_scalar(scanner)
    None => raise ParseError::UnexpectedEof(pos=scanner.position())
  }
}

///|
fn parse_flow_seq(scanner : Scanner) -> Yaml raise ParseError {
  scanner.expect('[')
  let items : Array[Yaml] = []
  scanner.skip_ws_and_comments()
  if scanner.eat(']') {
    return Yaml::Seq(items)
  }
  while true {
    let value = parse_flow_node(scanner)
    items.push(value)
    scanner.skip_ws_and_comments()
    if scanner.eat(']') {
      break
    }
    scanner.expect(',')
    scanner.skip_ws_and_comments()
    if scanner.eat(']') {
      break
    }
  }
  Yaml::Seq(items)
}

///|
fn parse_flow_map(scanner : Scanner) -> Yaml raise ParseError {
  scanner.expect('{')
  let items : Array[(Yaml, Yaml)] = []
  scanner.skip_ws_and_comments()
  if scanner.eat('}') {
    return Yaml::Map(items)
  }
  while true {
    let key = parse_flow_node(scanner)
    scanner.skip_ws_and_comments()
    scanner.expect(':')
    scanner.skip_ws_and_comments()
    let value = parse_flow_node(scanner)
    items.push((key, value))
    scanner.skip_ws_and_comments()
    if scanner.eat('}') {
      break
    }
    scanner.expect(',')
    scanner.skip_ws_and_comments()
    if scanner.eat('}') {
      break
    }
  }
  Yaml::Map(items)
}
