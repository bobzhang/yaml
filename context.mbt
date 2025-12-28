///|
priv struct TagContext {
  handles : Map[String, String]
  coerce_binary : Bool
}

///|
fn TagContext::new() -> TagContext {
  let handles : Map[String, String] = {}
  handles["!!"] = "tag:yaml.org,2002:"
  handles["!"] = "!"
  { handles, coerce_binary: true }
}

///|
fn TagContext::new_raw() -> TagContext {
  let handles : Map[String, String] = {}
  handles["!!"] = "tag:yaml.org,2002:"
  handles["!"] = "!"
  { handles, coerce_binary: false }
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
fn TagContext::expand(self : TagContext, full_tag : String) -> String {
  if !full_tag.has_prefix("!") {
    return full_tag
  }
  match full_tag.rev_find("!") {
    None => full_tag
    Some(idx) => {
      let handle = full_tag.view(end_offset=idx + 1).to_string()
      let suffix = full_tag.view(start_offset=idx + 1).to_string()
      match self.handles.get(handle) {
        Some(prefix) => prefix + suffix
        None => full_tag
      }
    }
  }
}
