//// Animator -- an application for program-generated drawings.

import builtins
import data
import drawing
import editor
import errors
import examples
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import parser
import render
import shape.{type Path}

pub const public_url = ""

pub const include_app_in_gallery = False

pub const video_url = ""

pub const include_video_in_gallery = False

const default_code =
  "fn draw(shape_slider: Int) -> List(Path) {\n  [Path(Line(Point(0, 0), Point(100, 100)), 0, 10, 2)]\n}\n"

// ── Model ─────────────────────────────────────────────────────────────────────

pub type Model {
  Model(
    source: String,
    code_open: Bool,
    output: String,
    shape_slider: Int,
    speed: Int,
    drawings: List(#(String, String)),
    selected: String,
  )
}

pub type Msg {
  SetCode(String)
  ToggleCode
  SetShape(String)
  SetSpeed(String)
  SelectDrawing(String)
  Restart
}

// ── Init ──────────────────────────────────────────────────────────────────────

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let library = data.load(examples.all)
  let source =
    list.key_find(library.drawings, library.selected)
    |> result.unwrap(default_code)

  #(
    Model(
      source: source,
      code_open: True,
      output: "",
      shape_slider: 10,
      speed: 1,
      drawings: library.drawings,
      selected: library.selected,
    ),
    effect.batch([
      editor.mount(source, SetCode),
      effect.from(fn(dispatch) { dispatch(SetCode(source)) }),
    ]),
  )
}

// ── Evaluation and animation ──────────────────────────────────────────────────

fn run_source(shape_slider: Int, source: String) -> Result(List(Path), String) {
  case parser.parse_program(source, builtins.global_frame()) {
    Error(msg) -> Error(msg)
    Ok(program) ->
      drawing.try_draw(shape_slider, program)
      |> result.map_error(errors.error_message)
  }
}

fn refresh(model: Model) -> #(Model, Effect(Msg)) {
  case run_source(model.shape_slider, model.source) {
    Ok(paths) -> {
      let rendered =
        list.map(paths, fn(path) { render.render_path(path, "#60a5fa") })

      #(
        Model(..model, output: ""),
        effect.from(fn(_dispatch) {
          render.set_drawing(rendered)
          render.reset_clock()
          render.set_speed(int.to_float(model.speed))
        }),
      )
    }

    Error(message) -> #(
      Model(..model, output: message),
      effect.from(fn(_dispatch) { render.set_drawing([]) }),
    )
  }
}

// ── Drawing library ───────────────────────────────────────────────────────────

fn save_library(model: Model) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    data.save(data.Library(model.drawings, model.selected))
  })
}

fn open_drawing(
  model: Model,
  name: String,
  source: String,
) -> #(Model, Effect(Msg)) {
  let updated =
    Model(
      ..model,
      selected: name,
      source: source,
      drawings: data.put(model.drawings, name, source),
    )

  let #(updated, animation) = refresh(updated)

  #(
    updated,
    effect.batch([
      animation,
      save_library(updated),
      editor.mount(source, SetCode),
    ]),
  )
}

// ── Update ────────────────────────────────────────────────────────────────────

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ToggleCode -> #(Model(..model, code_open: !model.code_open), effect.none())

    SetCode(text) -> {
      let updated =
        Model(
          ..model,
          source: text,
          drawings: data.put(model.drawings, model.selected, text),
        )

      let #(updated, animation) = refresh(updated)

      #(
        updated,
        effect.batch([
          animation,
          save_library(updated),
        ]),
      )
    }

    SetShape(text) ->
      case int.parse(text) {
        Ok(value) -> refresh(Model(..model, shape_slider: value))
        Error(_) -> #(model, effect.none())
      }

    SetSpeed(text) ->
      case int.parse(text) {
        Ok(value) -> #(
          Model(..model, speed: value),
          effect.from(fn(_dispatch) { render.set_speed(int.to_float(value)) }),
        )
        Error(_) -> #(model, effect.none())
      }

    SelectDrawing(name) ->
      case name {
        "" -> {
          let new_name = string.trim(data.prompt_drawing_name())

          case new_name {
            "" -> #(model, effect.none())

            _ ->
              case list.key_find(model.drawings, new_name) {
                Ok(source) -> open_drawing(model, new_name, source)
                Error(_) -> open_drawing(model, new_name, default_code)
              }
          }
        }

        _ ->
          case list.key_find(model.drawings, name) {
            Ok(source) -> open_drawing(model, name, source)
            Error(_) -> #(model, effect.none())
          }
      }

    Restart -> #(
      model,
      effect.from(fn(_dispatch) {
        render.reset_clock()
        render.set_speed(int.to_float(model.speed))
      }),
    )
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

pub fn view(model: Model) -> Element(Msg) {
  let app_class = case model.code_open {
    True -> "app"
    False -> "app code-hidden"
  }

  html.div([attr.class(app_class)], [
    html.div([attr.class("code-col")], [
      editor.view_panel(ToggleCode),
    ]),
    view_anim(model),
  ])
}

fn view_anim(model: Model) -> Element(Msg) {
  html.div([attr.class("canvas-area")], [
    view_reveal_code(model),
    view_controls(model),
    html.canvas([
      attr.id("animation-canvas"),
      attr.class("canvas"),
      attr.attribute("width", "1000"),
      attr.attribute("height", "1000"),
    ]),
    case model.output {
      "" -> element.none()

      message ->
        html.pre(
          [
            attr.class("output"),
            attr.attribute("role", "alert"),
          ],
          [html.text(message)],
        )
    },
  ])
}

fn view_library(model: Model) -> Element(Msg) {
  let options =
    list.map(model.drawings, fn(drawing) {
      let #(name, _) = drawing

      html.option(
        [
          attr.attribute("value", name),
          attr.selected(name == model.selected),
        ],
        name,
      )
    })

  html.label([], [
    html.text("Drawing: "),
    html.select(
      [
        attr.attribute("data-test-id", "drawing-select"),
        event.on_change(SelectDrawing),
      ],
      list.append(options, [
        html.option([attr.attribute("value", "")], "+ New drawing…"),
      ]),
    ),
  ])
}

fn view_controls(model: Model) -> Element(Msg) {
  html.div(
    [
      attr.class("controls"),
      attr.attribute(
        "style",
        "display:flex;flex-wrap:wrap;gap:16px;align-items:center;padding:12px;",
      ),
    ],
    [
      view_library(model),
      html.label([], [
        html.text("Shape: " <> int.to_string(model.shape_slider) <> " "),
        html.input([
          attr.attribute("type", "range"),
          attr.attribute("min", "0"),
          attr.attribute("max", "100"),
          attr.attribute("step", "1"),
          attr.attribute("value", int.to_string(model.shape_slider)),
          attr.attribute("data-test-id", "shape-slider"),
          event.on_input(SetShape),
        ]),
      ]),
      html.label([], [
        html.text("Speed: " <> int.to_string(model.speed) <> "× "),
        html.input([
          attr.attribute("type", "range"),
          attr.attribute("min", "-5"),
          attr.attribute("max", "5"),
          attr.attribute("step", "1"),
          attr.attribute("value", int.to_string(model.speed)),
          attr.attribute("data-test-id", "speed-slider"),
          event.on_input(SetSpeed),
        ]),
      ]),
      html.button([event.on_click(Restart)], [html.text("Restart")]),
    ],
  )
}

fn view_reveal_code(model: Model) -> Element(Msg) {
  case model.code_open {
    True -> element.none()

    False ->
      html.button(
        [
          attr.class("icon-btn reveal-code"),
          attr.attribute("title", "Show code"),
          event.on_click(ToggleCode),
        ],
        [html.text("⟩")],
      )
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
