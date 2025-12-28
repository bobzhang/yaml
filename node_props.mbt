///|
fn parse_node_props(scanner : Scanner) -> (String?, String?) raise ParseError {
  let mut tag : String? = None
  let mut anchor : String? = None
  let mut progressed = true
  while progressed {
    progressed = false
    if scanner.eat('!') {
      tag = Some(read_tag(scanner))
      progressed = true
    } else if scanner.eat('&') {
      anchor = Some(read_anchor(scanner))
      progressed = true
    }
    if progressed {
      scanner.skip_ws_and_comments()
    }
  }
  (tag, anchor)
}

///|
fn parse_alias(scanner : Scanner) -> String? raise ParseError {
  if scanner.eat('*') {
    Some(read_anchor(scanner))
  } else {
    None
  }
}

///|
fn apply_node_props(value : Yaml, tag : String?, anchor : String?) -> Yaml {
  let mut node = value
  if tag is Some(t) {
    node = Yaml::Tagged(tag=t, value=node)
  }
  if anchor is Some(a) {
    node = Yaml::Anchor(name=a, value=node)
  }
  node
}

///|
fn read_tag(scanner : Scanner) -> String {
  let sb = StringBuilder::new()
  while scanner.peek() is Some(c) && !is_prop_break(c) {
    ignore(scanner.advance())
    sb.write_char(c)
  }
  let body = sb.to_string()
  if body is "" {
    "!"
  } else {
    "!" + body
  }
}

///|
fn read_anchor(scanner : Scanner) -> String raise ParseError {
  let sb = StringBuilder::new()
  while scanner.peek() is Some(c) && is_anchor_char(c) {
    ignore(scanner.advance())
    sb.write_char(c)
  }
  let name = sb.to_string()
  if name is "" {
    raise ParseError::UnexpectedChar(pos=scanner.position(), found=' ')
  }
  name
}

///|
fn is_anchor_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c is '_' ||
  c is '-' ||
  c is '.'
}

///|
fn is_prop_break(c : Char) -> Bool {
  c.is_whitespace() || c is ',' || c is ':' || c is ']' || c is '}' || c is '#'
}
