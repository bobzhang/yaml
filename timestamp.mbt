///|
fn parse_tagged_timestamp(tag : String, raw : String) -> Yaml raise ParseError {
  if is_valid_timestamp(raw) {
    Yaml::String(raw)
  } else {
    raise ParseError::InvalidTagValue(tag~, value=raw)
  }
}

///|
fn is_valid_timestamp(raw : String) -> Bool {
  let chars = raw.to_array()
  if chars.length() < 10 {
    return false
  }
  let year = parse_four(chars, 0).unwrap_or(-1)
  if year < 0 {
    return false
  }
  if chars[4] != '-' || chars[7] != '-' {
    return false
  }
  let month = parse_two(chars, 5).unwrap_or(0)
  let day = parse_two(chars, 8).unwrap_or(0)
  if month < 1 || month > 12 {
    return false
  }
  let max_day = days_in_month(year, month)
  if day < 1 || day > max_day {
    return false
  }
  if chars.length() == 10 {
    return true
  }
  let sep = chars[10]
  if !(sep is 'T' || sep is 't' || sep is ' ') {
    return false
  }
  if chars.length() < 19 {
    return false
  }
  let hour = parse_two(chars, 11).unwrap_or(-1)
  let minute = parse_two(chars, 14).unwrap_or(-1)
  let second = parse_two(chars, 17).unwrap_or(-1)
  if chars[13] != ':' || chars[16] != ':' {
    return false
  }
  if hour < 0 || hour > 23 {
    return false
  }
  if minute < 0 || minute > 59 {
    return false
  }
  if second < 0 || second > 60 {
    return false
  }
  let mut idx = 19
  if idx < chars.length() && chars[idx] is '.' {
    idx = idx + 1
    let start = idx
    while idx < chars.length() && chars[idx].is_ascii_digit() {
      idx = idx + 1
    }
    if idx == start {
      return false
    }
  }
  if idx == chars.length() {
    return true
  }
  let tz = chars[idx]
  if tz is 'Z' || tz is 'z' {
    return idx + 1 == chars.length()
  }
  if tz is '+' || tz is '-' {
    idx = idx + 1
    if idx + 1 >= chars.length() {
      return false
    }
    let tz_hour = parse_two(chars, idx).unwrap_or(-1)
    if tz_hour < 0 || tz_hour > 23 {
      return false
    }
    idx = idx + 2
    if idx == chars.length() {
      return true
    }
    if chars[idx] != ':' {
      return false
    }
    idx = idx + 1
    if idx + 1 >= chars.length() {
      return false
    }
    let tz_minute = parse_two(chars, idx).unwrap_or(-1)
    if tz_minute < 0 || tz_minute > 59 {
      return false
    }
    idx = idx + 2
    return idx == chars.length()
  }
  false
}

///|
fn parse_two(chars : Array[Char], index : Int) -> Int? {
  if index + 1 >= chars.length() {
    return None
  }
  match digit_value(chars[index]) {
    None => None
    Some(a) =>
      match digit_value(chars[index + 1]) {
        None => None
        Some(b) => Some(a * 10 + b)
      }
  }
}

///|
fn parse_four(chars : Array[Char], index : Int) -> Int? {
  if index + 3 >= chars.length() {
    return None
  }
  match digit_value(chars[index]) {
    None => None
    Some(a) =>
      match digit_value(chars[index + 1]) {
        None => None
        Some(b) =>
          match digit_value(chars[index + 2]) {
            None => None
            Some(c) =>
              match digit_value(chars[index + 3]) {
                None => None
                Some(d) => Some(((a * 10 + b) * 10 + c) * 10 + d)
              }
          }
      }
  }
}

///|
fn digit_value(c : Char) -> Int? {
  if c.is_ascii_digit() {
    Some(c.to_int() - '0'.to_int())
  } else {
    None
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}
