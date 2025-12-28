///|
fn decode_base64(tag : String, raw : String) -> Bytes raise ParseError {
  let values : Array[Int] = []
  let mut seen_pad = false
  for c in raw {
    if c.is_whitespace() {
      continue
    }
    if c is '=' {
      seen_pad = true
      values.push(-1)
      continue
    }
    if seen_pad {
      raise ParseError::InvalidTagValue(tag~, value=raw)
    }
    match base64_value(c) {
      None => raise ParseError::InvalidTagValue(tag~, value=raw)
      Some(v) => values.push(v)
    }
  }
  let mut len = values.length()
  if len == 0 {
    return Bytes::from_array([])
  }
  if len % 4 != 0 {
    if seen_pad {
      raise ParseError::InvalidTagValue(tag~, value=raw)
    }
    let rem = len % 4
    if rem == 1 {
      raise ParseError::InvalidTagValue(tag~, value=raw)
    } else if rem == 2 {
      values.push(-1)
      values.push(-1)
    } else {
      values.push(-1)
    }
    len = values.length()
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < len {
    let v0 = values[i]
    let v1 = values[i + 1]
    let v2 = values[i + 2]
    let v3 = values[i + 3]
    if v0 < 0 || v1 < 0 {
      raise ParseError::InvalidTagValue(tag~, value=raw)
    }
    let b0 = (v0 << 2) | (v1 >> 4)
    out.push(b0.to_byte())
    if v2 < 0 {
      if v3 >= 0 {
        raise ParseError::InvalidTagValue(tag~, value=raw)
      }
      i = i + 4
      continue
    }
    let b1 = ((v1 & 0x0f) << 4) | (v2 >> 2)
    out.push(b1.to_byte())
    if v3 < 0 {
      i = i + 4
      continue
    }
    let b2 = ((v2 & 0x03) << 6) | v3
    out.push(b2.to_byte())
    i = i + 4
  }
  Bytes::from_array(out)
}

///|
fn base64_value(c : Char) -> Int? {
  if c.is_ascii_uppercase() {
    Some(c.to_int() - 'A'.to_int())
  } else if c.is_ascii_lowercase() {
    Some(c.to_int() - 'a'.to_int() + 26)
  } else if c.is_ascii_digit() {
    Some(c.to_int() - '0'.to_int() + 52)
  } else if c is '+' {
    Some(62)
  } else if c is '/' {
    Some(63)
  } else {
    None
  }
}
