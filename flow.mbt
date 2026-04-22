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
      if (tag is Some(_) || anchor is Some(_)) && scanner.peek() is Some('*') {
        raise ParseError::InvalidTagValue(tag="alias", value="*")
      }
      if tag is Some(_) || anchor is Some(_) {
        match scanner.peek() {
          Some(',') | Some(']') | Some('}') | Some(':') =>
            return apply_node_props(Yaml::Null, tag, anchor, ctx.coerce_binary)
          None =>
            return apply_node_props(Yaml::Null, tag, anchor, ctx.coerce_binary)
          _ => ()
        }
      }
      let value = parse_flow_value(ctx, scanner)
      apply_node_props(value, tag, anchor, ctx.coerce_binary)
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
    Some(_) => parse_flow_plain_scalar(scanner)
    None => raise ParseError::UnexpectedEof(pos=scanner.position())
  }
}

///|
fn parse_flow_plain_scalar(scanner : Scanner) -> Yaml raise ParseError {
  let start = scanner.position()
  let raw = parse_plain_scalar(scanner)
  if raw is "-" {
    raise ParseError::UnexpectedChar(pos=start, found='-')
  }
  parse_scalar_value(raw)
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
  let mut expect_item = true
  while true {
    scanner.skip_ws_and_comments()
    if expect_item {
      if is_flow_mapping_colon(scanner) {
        ignore(scanner.advance())
        scanner.skip_ws_and_comments()
        let value = if scanner.peek() is Some(',') ||
          scanner.peek() is Some(']') {
          Yaml::Null
        } else {
          parse_flow_node(ctx, scanner)
        }
        items.push(Yaml::Map([(Yaml::Null, value)]))
        expect_item = false
        continue
      }
      match scanner.peek() {
        Some('?') if is_flow_explicit_key(scanner) => {
          ignore(scanner.advance())
          scanner.skip_ws_and_comments()
          let key = if scanner.peek() is Some(':') ||
            scanner.peek() is Some(',') ||
            scanner.peek() is Some(']') {
            Yaml::Null
          } else {
            parse_flow_node(ctx, scanner)
          }
          scanner.skip_ws_and_comments()
          let value = if scanner.eat(':') {
            scanner.skip_ws_and_comments()
            if scanner.peek() is Some(',') || scanner.peek() is Some(']') {
              Yaml::Null
            } else {
              parse_flow_node(ctx, scanner)
            }
          } else if key is Yaml::Null {
            Yaml::Null
          } else {
            match scanner.peek() {
              None => raise ParseError::UnexpectedEof(pos=scanner.position())
              Some(found) =>
                raise ParseError::UnexpectedChar(pos=scanner.position(), found~)
            }
          }
          items.push(Yaml::Map([(key, value)]))
          expect_item = false
          continue
        }
        Some(']') =>
          raise ParseError::UnexpectedChar(pos=scanner.position(), found=']')
        Some(',') => {
          if items.length() == 0 {
            raise ParseError::UnexpectedChar(pos=scanner.position(), found=',')
          }
          ignore(scanner.advance())
          items.push(Yaml::Null)
          expect_item = true
          continue
        }
        _ => ()
      }
      let key_start_line = scanner.position().line
      let key = parse_flow_node(ctx, scanner)
      scanner.skip_ws_and_comments()
      if scanner.peek() is Some(':') {
        if scanner.position().line != key_start_line {
          raise ParseError::UnexpectedChar(pos=scanner.position(), found=':')
        }
        ignore(scanner.advance())
        scanner.skip_ws_and_comments()
        let value = if scanner.peek() is Some(',') ||
          scanner.peek() is Some(']') {
          Yaml::Null
        } else {
          parse_flow_node(ctx, scanner)
        }
        items.push(Yaml::Map([(key, value)]))
      } else {
        items.push(key)
      }
      expect_item = false
    } else {
      if scanner.eat(']') {
        break
      }
      scanner.expect(',')
      scanner.skip_ws_and_comments()
      if scanner.eat(']') {
        break
      }
      expect_item = true
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
      let key = if scanner.peek() is Some(':') ||
        scanner.peek() is Some(',') ||
        scanner.peek() is Some('}') {
        Yaml::Null
      } else {
        parse_flow_node(ctx, scanner)
      }
      scanner.skip_ws_and_comments()
      let value = if scanner.eat(':') {
        scanner.skip_ws_and_comments()
        if scanner.peek() is Some(',') || scanner.peek() is Some('}') {
          Yaml::Null
        } else {
          parse_flow_node(ctx, scanner)
        }
      } else if key is Yaml::Null {
        Yaml::Null
      } else {
        match scanner.peek() {
          None => raise ParseError::UnexpectedEof(pos=scanner.position())
          Some(found) =>
            raise ParseError::UnexpectedChar(pos=scanner.position(), found~)
        }
      }
      items.push((key, value))
    } else if is_flow_mapping_colon(scanner) {
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
      match scanner.peek() {
        Some(':') => {
          ignore(scanner.advance())
          scanner.skip_ws_and_comments()
          let value = if scanner.peek() is Some(',') ||
            scanner.peek() is Some('}') {
            Yaml::Null
          } else {
            parse_flow_node(ctx, scanner)
          }
          items.push((key, value))
        }
        Some(',') | Some('}') => items.push((key, Yaml::Null))
        _ => scanner.expect(':')
      }
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

///|
fn is_flow_mapping_colon(scanner : Scanner) -> Bool {
  match scanner.peek() {
    Some(':') =>
      match scanner.peek_next() {
        None => true
        Some(next) =>
          next.is_whitespace() || next is ',' || next is ']' || next is '}'
      }
    _ => false
  }
}
