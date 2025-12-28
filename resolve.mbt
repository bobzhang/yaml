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
    Map(items) =>
      Yaml::Map(
        items.map(pair => {
          let (k, v) = pair
          (resolve_node(k, anchors), resolve_node(v, anchors))
        }),
      )
    _ => value
  }
}
