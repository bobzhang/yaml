///|
fn parse_flow_node(
  ctx : TagContext,
  scanner : Scanner,
) -> Yaml raise ParseError {
  scanner.skip_ws_and_comments()
  match parse_alias(scanner) {
    Some(name) => Yaml::Alias(name)
    None => {
      let (tag, anchor) = parse_node_props(ctx, scanner)
      scanner.skip_ws_and_comments()
      let value = if tag is Some(_) {
        match scanner.peek() {
          Some('[') => parse_flow_value(ctx, scanner)
          Some('{') => parse_flow_value(ctx, scanner)
          Some('"') => parse_flow_value(ctx, scanner)
          Some('\'') => parse_flow_value(ctx, scanner)
          Some(_) => Yaml::String(parse_plain_scalar(scanner))
          None => raise ParseError::UnexpectedEof(pos=scanner.position())
        }
      } else {
        parse_flow_value(ctx, scanner)
      }
      apply_node_props(value, tag, anchor)
    }
  }
}

///|
fn parse_flow_value(
  ctx : TagContext,
  scanner : Scanner,
) -> Yaml raise ParseError {
  match scanner.peek() {
    Some('[') => parse_flow_seq(ctx, scanner)
    Some('{') => parse_flow_map(ctx, scanner)
    Some('"') => parse_scalar(scanner)
    Some('\'') => parse_scalar(scanner)
    Some(_) => parse_scalar(scanner)
    None => raise ParseError::UnexpectedEof(pos=scanner.position())
  }
}

///|
fn parse_flow_value_from_string(
  ctx : TagContext,
  text : String,
) -> Yaml raise ParseError {
  let scanner = Scanner::new(text)
  scanner.skip_ws_and_comments()
  let value = parse_flow_value(ctx, scanner)
  scanner.skip_ws_and_comments()
  match scanner.peek() {
    None => value
    Some(c) => raise ParseError::UnexpectedChar(pos=scanner.position(), found=c)
  }
}

///|
fn parse_flow_seq(ctx : TagContext, scanner : Scanner) -> Yaml raise ParseError {
  scanner.expect('[')
  let items : Array[Yaml] = []
  scanner.skip_ws_and_comments()
  if scanner.eat(']') {
    return Yaml::Seq(items)
  }
  while true {
    scanner.skip_ws_and_comments()
    if scanner.peek() is Some(',') {
      ignore(scanner.advance())
      items.push(Yaml::Null)
      scanner.skip_ws_and_comments()
      if scanner.eat(']') {
        break
      }
      continue
    }
    if scanner.peek() is Some(']') {
      ignore(scanner.advance())
      break
    }
    let value = parse_flow_node(ctx, scanner)
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
fn parse_flow_map(ctx : TagContext, scanner : Scanner) -> Yaml raise ParseError {
  scanner.expect('{')
  let items : Array[(Yaml, Yaml)] = []
  scanner.skip_ws_and_comments()
  if scanner.eat('}') {
    return Yaml::Map(items)
  }
  while true {
    if is_flow_explicit_key(scanner) {
      ignore(scanner.advance())
      scanner.skip_ws_and_comments()
      let key = parse_flow_node(ctx, scanner)
      scanner.skip_ws_and_comments()
      scanner.expect(':')
      scanner.skip_ws_and_comments()
      let value = if scanner.peek() is Some(',') || scanner.peek() is Some('}') {
        Yaml::Null
      } else {
        parse_flow_node(ctx, scanner)
      }
      items.push((key, value))
    } else if scanner.peek() is Some(':') {
      ignore(scanner.advance())
      scanner.skip_ws_and_comments()
      let value = if scanner.peek() is Some(',') || scanner.peek() is Some('}') {
        Yaml::Null
      } else {
        parse_flow_node(ctx, scanner)
      }
      items.push((Yaml::Null, value))
    } else {
      let key = parse_flow_node(ctx, scanner)
      scanner.skip_ws_and_comments()
      scanner.expect(':')
      scanner.skip_ws_and_comments()
      let value = if scanner.peek() is Some(',') || scanner.peek() is Some('}') {
        Yaml::Null
      } else {
        parse_flow_node(ctx, scanner)
      }
      items.push((key, value))
    }
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

///|
fn is_flow_explicit_key(scanner : Scanner) -> Bool {
  match scanner.peek() {
    Some('?') =>
      match scanner.peek_next() {
        Some(next) => next.is_whitespace()
        None => false
      }
    _ => false
  }
}
