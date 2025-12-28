///|
fn parse_node_props(
  ctx : TagContext,
  scanner : Scanner,
) -> (String?, String?) raise ParseError {
  let mut tag : String? = None
  let mut anchor : String? = None
  let mut progressed = true
  while progressed {
    progressed = false
    if scanner.eat('!') {
      tag = Some(read_tag(ctx, scanner))
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
fn apply_node_props(
  value : Yaml,
  tag : String?,
  anchor : String?,
  coerce_binary : Bool,
) -> Yaml raise ParseError {
  let (base, existing_tag, existing_anchor) = extract_node_props(value)
  let final_tag = match tag {
    Some(t) =>
      match existing_tag {
        Some(_) =>
          raise ParseError::InvalidTagValue(tag="tag", value="<duplicate-tag>")
        None => Some(t)
      }
    None => existing_tag
  }
  let final_anchor = match anchor {
    Some(a) =>
      match existing_anchor {
        Some(_) =>
          raise ParseError::InvalidTagValue(tag="anchor", value="<duplicate-anchor>")
        None => Some(a)
      }
    None => existing_anchor
  }
  let mut node = base
  match final_tag {
    None => ()
    Some(t) => {
      if !coerce_binary && is_core_tag(t, "binary") {
        node = node
      } else {
        node = coerce_tag(t, node)
      }
      node = Yaml::Tagged(tag=t, value=node)
    }
  }
  match final_anchor {
    None => ()
    Some(a) => node = Yaml::Anchor(name=a, value=node)
  }
  node
}

///|
fn extract_node_props(
  value : Yaml,
) -> (Yaml, String?, String?) raise ParseError {
  match value {
    Anchor(name~, value~) => {
      let (base, tag, anchor) = extract_node_props(value)
      if anchor is Some(_) {
        raise ParseError::InvalidTagValue(tag="anchor", value="<duplicate-anchor>")
      }
      (base, tag, Some(name))
    }
    Tagged(tag~, value~) => {
      let (base, existing_tag, anchor) = extract_node_props(value)
      if existing_tag is Some(_) {
        raise ParseError::InvalidTagValue(tag="tag", value="<duplicate-tag>")
      }
      (base, Some(tag), anchor)
    }
    _ => (value, None, None)
  }
}

///|
///|
fn coerce_tag(tag : String, value : Yaml) -> Yaml raise ParseError {
  if is_core_tag(tag, "null") {
    return Yaml::Null
  }
  if is_core_tag(tag, "bool") {
    match value {
      Bool(_) => value
      String(s) => parse_tagged_bool(tag, s)
      _ => value
    }
  } else if is_core_tag(tag, "int") {
    match value {
      Int(_) => value
      String(s) => parse_tagged_int(tag, s)
      _ => value
    }
  } else if is_core_tag(tag, "float") {
    match value {
      Float(_) => value
      String(s) => parse_tagged_float(tag, s)
      _ => value
    }
  } else if is_core_tag(tag, "binary") {
    match value {
      Binary(_) => value
      String(s) => parse_tagged_binary(tag, s)
      _ => raise ParseError::InvalidTagValue(tag~, value="<non-scalar>")
    }
  } else if is_core_tag(tag, "timestamp") {
    match value {
      String(s) => parse_tagged_timestamp(tag, s)
      _ => raise ParseError::InvalidTagValue(tag~, value="<non-scalar>")
    }
  } else if is_core_tag(tag, "map") {
    validate_tagged_map(tag, value)
  } else if is_core_tag(tag, "seq") {
    validate_tagged_seq(tag, value)
  } else if is_core_tag(tag, "set") {
    validate_tagged_set(tag, value)
  } else if is_core_tag(tag, "omap") {
    validate_tagged_omap(tag, value)
  } else if is_core_tag(tag, "pairs") {
    validate_tagged_pairs(tag, value)
  } else if is_core_tag(tag, "str") {
    match value {
      String(_) => value
      Null => Yaml::String("")
      Bool(b) => Yaml::String(b.to_string())
      Int(i) => Yaml::String(i.to_string())
      Float(f) => Yaml::String(f.to_string())
      _ => value
    }
  } else {
    value
  }
}

///|
fn parse_tagged_bool(tag : String, raw : String) -> Yaml raise ParseError {
  let lowered = raw.to_lower()
  if lowered is "true" {
    Yaml::Bool(true)
  } else if lowered is "false" {
    Yaml::Bool(false)
  } else {
    raise ParseError::InvalidTagValue(tag~, value=raw)
  }
}

///|
fn parse_tagged_int(tag : String, raw : String) -> Yaml raise ParseError {
  match parse_number(raw) {
    Some(Yaml::Int(v)) => Yaml::Int(v)
    _ => raise ParseError::InvalidTagValue(tag~, value=raw)
  }
}

///|
fn parse_tagged_float(tag : String, raw : String) -> Yaml raise ParseError {
  match parse_number(raw) {
    Some(Yaml::Float(v)) => Yaml::Float(v)
    Some(Yaml::Int(v)) => Yaml::Float(Float::from_int(v))
    _ => raise ParseError::InvalidTagValue(tag~, value=raw)
  }
}

///|
fn parse_tagged_binary(tag : String, raw : String) -> Yaml raise ParseError {
  Yaml::Binary(decode_base64(tag, raw))
}

///|
fn validate_tagged_map(tag : String, value : Yaml) -> Yaml raise ParseError {
  match value {
    Map(_) => value
    _ => raise ParseError::InvalidTagValue(tag~, value="<non-map>")
  }
}

///|
fn validate_tagged_seq(tag : String, value : Yaml) -> Yaml raise ParseError {
  match value {
    Seq(_) => value
    _ => raise ParseError::InvalidTagValue(tag~, value="<non-seq>")
  }
}

///|
fn validate_tagged_set(tag : String, value : Yaml) -> Yaml raise ParseError {
  match value {
    Map(items) => {
      for pair in items {
        if pair.1 != Yaml::Null && pair.1 != Yaml::String("") {
          raise ParseError::InvalidTagValue(tag~, value="<non-null>")
        }
      }
      value
    }
    _ => raise ParseError::InvalidTagValue(tag~, value="<non-map>")
  }
}

///|
fn validate_tagged_pairs(tag : String, value : Yaml) -> Yaml raise ParseError {
  match value {
    Seq(items) => {
      for item in items {
        match item {
          Map(entries) =>
            if entries.length() != 1 {
              raise ParseError::InvalidTagValue(tag~, value="<non-pair>")
            }
          _ => raise ParseError::InvalidTagValue(tag~, value="<non-map>")
        }
      }
      value
    }
    _ => raise ParseError::InvalidTagValue(tag~, value="<non-seq>")
  }
}

///|
fn validate_tagged_omap(tag : String, value : Yaml) -> Yaml raise ParseError {
  match value {
    Seq(items) => {
      let seen : Array[Yaml] = []
      for item in items {
        match item {
          Map(entries) => {
            if entries.length() != 1 {
              raise ParseError::InvalidTagValue(tag~, value="<non-pair>")
            }
            let key = entries[0].0
            if find_yaml_index(seen, key) is Some(_) {
              raise ParseError::InvalidTagValue(tag~, value="<duplicate-key>")
            }
            seen.push(key)
          }
          _ => raise ParseError::InvalidTagValue(tag~, value="<non-map>")
        }
      }
      value
    }
    _ => raise ParseError::InvalidTagValue(tag~, value="<non-seq>")
  }
}

///|
fn find_yaml_index(items : Array[Yaml], key : Yaml) -> Int? {
  for i in 0..<items.length() {
    if items[i] == key {
      return Some(i)
    }
  }
  None
}

///|
fn read_tag(ctx : TagContext, scanner : Scanner) -> String raise ParseError {
  if scanner.eat('<') {
    return read_verbatim_tag(scanner)
  }
  let sb = StringBuilder::new()
  while scanner.peek() is Some(c) && !is_prop_break(c) {
    ignore(scanner.advance())
    sb.write_char(c)
  }
  let body = sb.to_string()
  let full = if body is "" { "!" } else { "!" + body }
  for c in body {
    if c is '{' || c is '}' || c is '[' || c is ']' {
      raise ParseError::InvalidTagValue(tag="tag", value=full)
    }
  }
  ctx.expand(full)
}

///|
fn read_verbatim_tag(scanner : Scanner) -> String raise ParseError {
  let sb = StringBuilder::new()
  while true {
    match scanner.peek() {
      None => raise ParseError::UnexpectedEof(pos=scanner.position())
      Some('>') => {
        ignore(scanner.advance())
        return sb.to_string()
      }
      Some(c) => {
        ignore(scanner.advance())
        sb.write_char(c)
      }
    }
  } else {
    sb.to_string()
  }
}

///|
fn is_core_tag(tag : String, name : String) -> Bool {
  let full = "tag:yaml.org,2002:" + name
  let short = "!!" + name
  let verbatim = "!<tag:yaml.org,2002:" + name + ">"
  tag == full || tag == short || tag == verbatim
}

///|
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
  if c.is_whitespace() {
    return false
  }
  !is_anchor_break(c)
}

///|
fn is_anchor_break(c : Char) -> Bool {
  c is '[' ||
  c is ']' ||
  c is '{' ||
  c is '}' ||
  c is ',' ||
  c is '?' ||
  c is '#' ||
  c is '&' ||
  c is '*' ||
  c is '!' ||
  c is '|' ||
  c is '>' ||
  c is '\'' ||
  c is '"' ||
  c is '%' ||
  c is '@' ||
  c is '`'
}

///|
fn is_prop_break(c : Char) -> Bool {
  c.is_whitespace() || c is ',' || c is ':' || c is ']' || c is '}' || c is '#'
}
