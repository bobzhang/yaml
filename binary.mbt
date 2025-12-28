///|
pub fn decode_base64(tag : String, raw : String) -> Bytes raise ParseError {
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
pub fn encode_base64(bytes : Bytes) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i + 2 < len {
    let b0 = bytes[i].to_int()
    let b1 = bytes[i + 1].to_int()
    let b2 = bytes[i + 2].to_int()
    let x0 = (b0 & 0xfc) >> 2
    let x1 = ((b0 & 0x03) << 4) | ((b1 & 0xf0) >> 4)
    let x2 = ((b1 & 0x0f) << 2) | ((b2 & 0xc0) >> 6)
    let x3 = b2 & 0x3f
    sb.write_char(alphabet.get_char(x0).unwrap())
    sb.write_char(alphabet.get_char(x1).unwrap())
    sb.write_char(alphabet.get_char(x2).unwrap())
    sb.write_char(alphabet.get_char(x3).unwrap())
    i = i + 3
  }
  let rem = len - i
  if rem == 1 {
    let b0 = bytes[i].to_int()
    let x0 = (b0 & 0xfc) >> 2
    let x1 = (b0 & 0x03) << 4
    sb.write_char(alphabet.get_char(x0).unwrap())
    sb.write_char(alphabet.get_char(x1).unwrap())
    sb.write_char('=')
    sb.write_char('=')
  } else if rem == 2 {
    let b0 = bytes[i].to_int()
    let b1 = bytes[i + 1].to_int()
    let x0 = (b0 & 0xfc) >> 2
    let x1 = ((b0 & 0x03) << 4) | ((b1 & 0xf0) >> 4)
    let x2 = (b1 & 0x0f) << 2
    sb.write_char(alphabet.get_char(x0).unwrap())
    sb.write_char(alphabet.get_char(x1).unwrap())
    sb.write_char(alphabet.get_char(x2).unwrap())
    sb.write_char('=')
  }
  sb.to_string()
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
