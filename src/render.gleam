//// Convert shapes into polylines for the animated canvas.

import gleam/int
import gleam/list
import shape.{
  type Path, type Point, Circle, Ellipse, Line, Point, Rectangle, Square,
}

pub type RenderPath {
  RenderPath(
    points: List(Point),
    thickness: Float,
    color: String,
    start: Float,
    end: Float,
  )
}

@external(javascript, "./canvas.mjs", "setDrawing")
pub fn set_drawing(paths: List(RenderPath)) -> Nil

@external(javascript, "./canvas.mjs", "setSpeed")
pub fn set_speed(rate: Float) -> Nil

@external(javascript, "./canvas.mjs", "resetClock")
pub fn reset_clock() -> Nil

@external(javascript, "./render_math.mjs", "cosine")
fn cosine(angle: Float) -> Float

@external(javascript, "./render_math.mjs", "sine")
fn sine(angle: Float) -> Float

pub fn render_path(path: Path, color: String) -> RenderPath {
  let points = case path.shape {
    Line(a, b) -> [a, b]

    Circle(center, radius) -> ellipse_points(center, radius, radius)

    Square(center, size) -> rectangle_points(center, size, size)

    Rectangle(center, width, height) -> rectangle_points(center, width, height)

    Ellipse(center, width, height) ->
      ellipse_points(center, width /. 2.0, height /. 2.0)
  }

  RenderPath(points, path.thickness, color, path.start, path.end)
}

fn rectangle_points(center: Point, width: Float, height: Float) -> List(Point) {
  let half_width = width /. 2.0
  let half_height = height /. 2.0

  let top_left = Point(center.x -. half_width, center.y -. half_height)

  [
    top_left,
    Point(center.x +. half_width, center.y -. half_height),
    Point(center.x +. half_width, center.y +. half_height),
    Point(center.x -. half_width, center.y +. half_height),
    top_left,
  ]
}

fn ellipse_points(
  center: Point,
  radius_x: Float,
  radius_y: Float,
) -> List(Point) {
  let first = Point(center.x +. radius_x, center.y)

  let middle = ellipse_middle(center, radius_x, radius_y, 1, [])

  [first, ..list.append(middle, [first])]
}

fn ellipse_middle(
  center: Point,
  radius_x: Float,
  radius_y: Float,
  index: Int,
  accumulated: List(Point),
) -> List(Point) {
  case index >= 96 {
    True -> list.reverse(accumulated)

    False -> {
      let angle = 2.0 *. 3.141592653589793 *. int.to_float(index) /. 96.0

      let point =
        Point(
          center.x +. radius_x *. cosine(angle),
          center.y +. radius_y *. sine(angle),
        )

      ellipse_middle(center, radius_x, radius_y, index + 1, [
        point,
        ..accumulated
      ])
    }
  }
}
