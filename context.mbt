///|
priv struct TagContext {
  handles : Map[String, String]
  coerce_binary : Bool
  mut seen_yaml : Bool
}

///|
fn TagContext::new() -> TagContext {
  let handles : Map[String, String] = {}
  handles["!!"] = "tag:yaml.org,2002:"
  handles["!"] = "!"
  { handles, coerce_binary: true, seen_yaml: false }
}

///|
fn TagContext::new_raw() -> TagContext {
  let handles : Map[String, String] = {}
  handles["!!"] = "tag:yaml.org,2002:"
  handles["!"] = "!"
  { handles, coerce_binary: false, seen_yaml: false }
}

///|
fn TagContext::set_handle(
  self : TagContext,
  handle : String,
  prefix : String,
) -> Unit {
  self.handles[handle] = prefix
}

///|
fn TagContext::expand(
  self : TagContext,
  full_tag : String,
) -> String raise ParseError {
  if !full_tag.has_prefix("!") {
    return full_tag
  }
  match full_tag.rev_find("!") {
    None => decode_tag_uri(full_tag)
    Some(idx) => {
      let handle = full_tag.view(end_offset=idx + 1).to_string()
      let suffix = full_tag.view(start_offset=idx + 1).to_string()
      match self.handles.get(handle) {
        Some(prefix) => decode_tag_uri(prefix + suffix)
        None => raise ParseError::InvalidTagValue(tag="tag", value=full_tag)
      }
    }
  }
}

///|
fn decode_tag_uri(text : String) -> String {
  let chars = text.to_array()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c is '%' && i + 2 < chars.length() {
      let hi = tag_hex_value(chars[i + 1])
      let lo = tag_hex_value(chars[i + 2])
      if hi >= 0 && lo >= 0 {
        let code = hi * 16 + lo
        match code.to_char() {
          Some(decoded) => sb.write_char(decoded)
          None => {
            sb.write_char(c)
            sb.write_char(chars[i + 1])
            sb.write_char(chars[i + 2])
          }
        }
        i = i + 3
        continue
      }
    }
    sb.write_char(c)
    i = i + 1
  }
  sb.to_string()
}

///|
fn tag_hex_value(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    -1
  }
}
