//// The library of saved drawings.

import gleam/int
import gleam/list
import gleam/string

pub type Library {
  Library(drawings: List(#(String, String)), selected: String)
}

const storage_key = "animator-library-v1"

@external(javascript, "./data_ffi.mjs", "storageGet")
pub fn storage_get(key: String) -> Result(String, Nil)

@external(javascript, "./data_ffi.mjs", "storageSet")
pub fn storage_set(key: String, value: String) -> Nil

@external(javascript, "./data_ffi.mjs", "promptDrawingName")
pub fn prompt_drawing_name() -> String

// Count and split using Unicode codepoints consistently.
fn pack(text: String) -> String {
  let size =
    text
    |> string.to_utf_codepoints
    |> list.length

  int.to_string(size) <> ":" <> text
}

fn unpack(text: String) -> Result(#(String, String), Nil) {
  case string.split_once(text, ":") {
    Error(_) -> Error(Nil)

    Ok(#(size, remaining)) ->
      case int.parse(size) {
        Error(_) -> Error(Nil)

        Ok(n) -> {
          let codepoints = string.to_utf_codepoints(remaining)

          case n >= 0 && n <= list.length(codepoints) {
            False -> Error(Nil)

            True -> {
              let #(first, rest) = list.split(codepoints, n)

              Ok(#(
                string.from_utf_codepoints(first),
                string.from_utf_codepoints(rest),
              ))
            }
          }
        }
      }
  }
}

fn encode_drawings(drawings: List(#(String, String))) -> String {
  case drawings {
    [] -> ""

    [#(name, source), ..rest] ->
      pack(name) <> pack(source) <> encode_drawings(rest)
  }
}

fn decode_drawings(text: String) -> Result(List(#(String, String)), Nil) {
  case text {
    "" -> Ok([])

    _ ->
      case unpack(text) {
        Error(_) -> Error(Nil)

        Ok(#(name, remaining)) ->
          case unpack(remaining) {
            Error(_) -> Error(Nil)

            Ok(#(source, remaining)) ->
              case decode_drawings(remaining) {
                Error(_) -> Error(Nil)
                Ok(rest) -> Ok([#(name, source), ..rest])
              }
          }
      }
  }
}

pub fn save(library: Library) -> Nil {
  storage_set(
    storage_key,
    pack(library.selected) <> encode_drawings(library.drawings),
  )
}

pub fn load(defaults: List(#(String, String))) -> Library {
  let fallback = Library(defaults, first_name(defaults))

  case storage_get(storage_key) {
    Error(_) -> fallback

    Ok(text) ->
      case unpack(text) {
        Error(_) -> fallback

        Ok(#(selected, remaining)) ->
          case decode_drawings(remaining) {
            Error(_) -> fallback
            Ok([]) -> fallback

            Ok(drawings) ->
              case list.key_find(drawings, selected) {
                Ok(_) -> Library(drawings, selected)
                Error(_) -> Library(drawings, first_name(drawings))
              }
          }
      }
  }
}

fn first_name(drawings: List(#(String, String))) -> String {
  case drawings {
    [] -> ""
    [#(name, _), ..] -> name
  }
}

pub fn put(
  drawings: List(#(String, String)),
  name: String,
  source: String,
) -> List(#(String, String)) {
  case drawings {
    [] -> [#(name, source)]

    [#(existing, old_source), ..rest] ->
      case existing == name {
        True -> [#(name, source), ..rest]
        False -> [#(existing, old_source), ..put(rest, name, source)]
      }
  }
}
