///|
fn main {
  let args = @env.args()
  let result : Result[Unit, Error] = try? run(args)
  match result {
    Ok(_) => ()
    Err(err) => {
      println(err.to_string())
      panic()
    }
  }
}

///|
fn run(args : Array[String]) -> Unit raise {
  let idx = if args.length() > 0 { 1 } else { 0 }
  if args.length() - idx < 2 {
    fail("usage: yamlsuite <tree|json> <base64>")
  }
  let mode = args[idx]
  let payload = args[idx + 1]
  let bytes = @yaml.decode_base64("base64", payload)
  let input = @encoding/utf8.decode(bytes)
  if mode is "tree" {
    let docs = @yaml.parse_yaml_stream_raw(input)
    let json = Json::array(docs.map(yaml_to_tree_json))
    println(json.stringify())
  } else if mode is "json" {
    let docs = @yaml.parse_yaml_stream(input)
    if docs.length() == 1 {
      let json = yaml_to_json_value(docs[0])
      println(json.stringify())
    } else {
      let json = Json::array(docs.map(yaml_to_json_value))
      println(json.stringify())
    }
  } else {
    fail("unknown mode: " + mode)
  }
}

///|
fn yaml_to_tree_json(value : @yaml.Yaml) -> Json {
  match value {
    Null => tree_obj("Null", [])
    Bool(b) => tree_obj("Bool", [("value", Json::boolean(b))])
    Int(i) => tree_obj("Int", [("value", Json::string(i.to_string()))])
    Float(f) =>
      tree_obj("Float", [("value", float_to_json_value(f))])
    String(s) => tree_obj("String", [("value", Json::string(s))])
    Binary(bytes) =>
      tree_obj(
        "Binary",
        [("value", Json::string(@yaml.encode_base64(bytes)))],
      )
    Seq(items) =>
      tree_obj(
        "Seq",
        [("items", Json::array(items.map(yaml_to_tree_json)))],
      )
    Map(items) =>
      tree_obj(
        "Map",
        [("items", Json::array(items.map(pair_to_json)))],
      )
    Alias(name) => tree_obj("Alias", [("name", Json::string(name))])
    Anchor(name~, value~) =>
      tree_obj(
        "Anchor",
        [("name", Json::string(name)), ("value", yaml_to_tree_json(value))],
      )
    Tagged(tag~, value~) =>
      tree_obj(
        "Tagged",
        [("tag", Json::string(tag)), ("value", yaml_to_tree_json(value))],
      )
  }
}

///|
fn pair_to_json(pair : (@yaml.Yaml, @yaml.Yaml)) -> Json {
  let (key, value) = pair
  Json::array([yaml_to_tree_json(key), yaml_to_tree_json(value)])
}

///|
fn tree_obj(kind : String, fields : Array[(String, Json)]) -> Json {
  let obj : Map[String, Json] = {}
  obj["type"] = Json::string(kind)
  for field in fields {
    let (key, value) = field
    obj[key] = value
  }
  Json::object(obj)
}

///|
fn float_to_json_value(value : Float) -> Json {
  if value.is_nan() {
    Json::string("nan")
  } else if value.is_pos_inf() {
    Json::string("inf")
  } else if value.is_neg_inf() {
    Json::string("-inf")
  } else {
    Json::number(value.to_double())
  }
}

///|
fn yaml_to_json_value(value : @yaml.Yaml) -> Json raise @yaml.ParseError {
  match value {
    Null => Json::null()
    Bool(b) => Json::boolean(b)
    Int(i) => Json::number(Double::from_int(i))
    Float(f) => float_to_json_value(f)
    String(s) => Json::string(s)
    Binary(bytes) => Json::string(@yaml.encode_base64(bytes))
    Seq(items) => Json::array(items.map(yaml_to_json_value))
    Map(items) => map_to_json(items)
    Anchor(name~, value~) => {
      ignore(name)
      yaml_to_json_value(value)
    }
    Tagged(tag~, value~) => {
      ignore(tag)
      yaml_to_json_value(value)
    }
    Alias(name) =>
      raise @yaml.ParseError::InvalidTagValue(tag="alias", value=name)
  }
}

///|
fn map_to_json(
  items : Array[(@yaml.Yaml, @yaml.Yaml)],
) -> Json raise @yaml.ParseError {
  let obj : Map[String, Json] = {}
  for pair in items {
    let (key, value) = pair
    let key_value = strip_props(key)
    match key_value {
      String(s) => obj[s] = yaml_to_json_value(value)
      _ =>
        raise @yaml.ParseError::InvalidTagValue(
          tag="json",
          value="non-string key",
        )
    }
  }
  Json::object(obj)
}

///|
fn strip_props(value : @yaml.Yaml) -> @yaml.Yaml {
  match value {
    Anchor(name~, value~) => {
      ignore(name)
      strip_props(value)
    }
    Tagged(tag~, value~) => {
      ignore(tag)
      strip_props(value)
    }
    _ => value
  }
}
