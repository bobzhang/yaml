///|
pub fn resolve_aliases(value : Yaml) -> Yaml raise ParseError {
  let anchors : Map[String, Yaml] = {}
  resolve_node(value, anchors)
}

///|
fn resolve_node(
  value : Yaml,
  anchors : Map[String, Yaml],
) -> Yaml raise ParseError {
  match value {
    Alias(name) =>
      match anchors.get(name) {
        Some(v) => v
        None => raise ParseError::UnknownAnchor(name~)
      }
    Anchor(name~, value~) => {
      let resolved = resolve_node(value, anchors)
      anchors[name] = resolved
      Yaml::Anchor(name~, value=resolved)
    }
    Tagged(tag~, value~) =>
      Yaml::Tagged(tag~, value=resolve_node(value, anchors))
    Seq(items) => Yaml::Seq(items.map(item => resolve_node(item, anchors)))
    Map(items) => resolve_map(items, anchors)
    _ => value
  }
}

///|
fn resolve_map(
  items : Array[(Yaml, Yaml)],
  anchors : Map[String, Yaml],
) -> Yaml raise ParseError {
  let resolved : Array[(Yaml, Yaml)] = items.map(pair => {
    let (k, v) = pair
    (resolve_node(k, anchors), resolve_node(v, anchors))
  })
  Yaml::Map(merge_entries(resolved))
}

///|
fn merge_entries(
  items : Array[(Yaml, Yaml)],
) -> Array[(Yaml, Yaml)] raise ParseError {
  let result : Array[(Yaml, Yaml)] = []
  for pair in items {
    let (key, value) = pair
    if is_merge_key(key) {
      merge_value(value, result)
    } else {
      upsert_entry(result, key, value)
    }
  }
  result
}

///|
fn merge_value(
  value : Yaml,
  result : Array[(Yaml, Yaml)],
) -> Unit raise ParseError {
  match value {
    Map(items) => merge_map_items(items, result)
    Seq(items) =>
      for item in items {
        match item {
          Map(map_items) => merge_map_items(map_items, result)
          _ =>
            raise ParseError::InvalidMerge(
              detail="merge sequence must contain maps",
            )
        }
      }
    _ =>
      raise ParseError::InvalidMerge(
        detail="merge value must be map or sequence",
      )
  }
}

///|
fn merge_map_items(
  items : Array[(Yaml, Yaml)],
  result : Array[(Yaml, Yaml)],
) -> Unit {
  for pair in items {
    let (key, value) = pair
    if find_key_index(result, key) is None {
      result.push((key, value))
    }
  }
}

///|
fn upsert_entry(result : Array[(Yaml, Yaml)], key : Yaml, value : Yaml) -> Unit {
  match find_key_index(result, key) {
    None => result.push((key, value))
    Some(index) => result[index] = (key, value)
  }
}

///|
fn find_key_index(items : Array[(Yaml, Yaml)], key : Yaml) -> Int? {
  for i in 0..<items.length() {
    if items[i].0 == key {
      return Some(i)
    }
  }
  None
}

///|
fn is_merge_key(key : Yaml) -> Bool {
  match key {
    String("<<") => true
    Tagged(tag~, value~) => is_merge_tag(tag) || value is String("<<")
    _ => false
  }
}

///|
fn is_merge_tag(tag : String) -> Bool {
  tag is "!!merge" ||
  tag is "!<tag:yaml.org,2002:merge>" ||
  tag is "tag:yaml.org,2002:merge"
}
