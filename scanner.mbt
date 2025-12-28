///|
priv struct Scanner {
  input : String
  mut pos : Int
  mut line : Int
  mut column : Int
}

///|
fn Scanner::new(input : String) -> Scanner {
  { input, pos: 0, line: 1, column: 1 }
}

///|
fn Scanner::position(self : Scanner) -> Position {
  { line: self.line, column: self.column }
}

///|
fn Scanner::peek(self : Scanner) -> Char? {
  self.input.get_char(self.pos)
}

///|
fn Scanner::advance(self : Scanner) -> Char? {
  match self.peek() {
    None => None
    Some(c) => {
      let step = c.utf16_len()
      self.pos = self.pos + step
      if c is '\r' {
        if self.peek() is Some('\n') {
          self.pos = self.pos + '\n'.utf16_len()
        }
        self.line = self.line + 1
        self.column = 1
        Some('\n')
      } else if c is '\n' {
        self.line = self.line + 1
        self.column = 1
        Some('\n')
      } else {
        self.column = self.column + 1
        Some(c)
      }
    }
  }
}

///|
fn Scanner::eat(self : Scanner, ch : Char) -> Bool {
  match self.peek() {
    Some(c) if c == ch => {
      ignore(self.advance())
      true
    }
    _ => false
  }
}

///|
fn Scanner::expect(self : Scanner, ch : Char) -> Unit raise ParseError {
  if !self.eat(ch) {
    match self.peek() {
      None => raise ParseError::UnexpectedEof(pos=self.position())
      Some(found) => raise ParseError::UnexpectedChar(pos=self.position(), found=found)
    }
  }
}

///|
fn Scanner::skip_ws(self : Scanner) -> Unit {
  while self.peek() is Some(c) && (c.is_whitespace()) {
    ignore(self.advance())
  }
}

///|
fn Scanner::skip_comment(self : Scanner) -> Unit {
  if self.peek() is Some('#') {
    ignore(self.advance())
    while self.peek() is Some(c) && !(c is '\n' || c is '\r') {
      ignore(self.advance())
    }
  }
}

///|
fn Scanner::skip_ws_and_comments(self : Scanner) -> Unit {
  let mut progressed = true
  while progressed {
    progressed = false
    let before = self.pos
    self.skip_ws()
    self.skip_comment()
    if self.pos != before {
      progressed = true
    }
  }
}
