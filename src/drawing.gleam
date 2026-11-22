//// Evaluate a drawing and convert its values into geometry.

import errors.{type EvalError, BadDrawing, PathLimit}
import evaluator.{type GlobalFrame, type Value, VData, VInt, VList}
import gleam/int
import gleam/list
import gleam/result
import limits
import shape.{
  type Path, type Point, type Shape, Circle, Ellipse, Line, Path, Point,
  Rectangle, Square,
}

pub fn try_draw(
  shape_slider: Int,
  global: GlobalFrame,
) -> Result(List(Path), EvalError) {
  case evaluator.run("draw", [VInt(shape_slider)], global) {
    Ok(VList(items)) ->
      case list.length(items) > limits.path_limit {
        True -> Error(PathLimit)
        False -> list.try_map(items, to_path)
      }

    Ok(_) -> Error(BadDrawing("return value of draw is not a list"))

    Error(err) -> Error(err)
  }
}

fn to_path(v: Value) -> Result(Path, EvalError) {
  case v {
    VData("Path", [geometry, VInt(start), VInt(end), VInt(thickness)]) -> {
      use s <- result.try(to_shape(geometry))

      Ok(Path(
        s,
        int.to_float(start),
        int.to_float(end),
        int.to_float(thickness),
      ))
    }

    _ -> Error(BadDrawing("some element is not a well-formed path"))
  }
}

fn to_shape(v: Value) -> Result(Shape, EvalError) {
  case v {
    VData("Line", [start, end]) -> {
      use a <- result.try(to_point(start))
      use b <- result.try(to_point(end))
      Ok(Line(a, b))
    }

    VData("Circle", [center, VInt(radius)]) -> {
      use p <- result.try(to_point(center))
      use r <- result.try(dimension(radius))
      Ok(Circle(p, r))
    }

    VData("Square", [center, VInt(size)]) -> {
      use p <- result.try(to_point(center))
      use s <- result.try(dimension(size))
      Ok(Square(p, s))
    }

    VData("Rectangle", [center, VInt(width), VInt(height)]) -> {
      use p <- result.try(to_point(center))
      use w <- result.try(dimension(width))
      use h <- result.try(dimension(height))
      Ok(Rectangle(p, w, h))
    }

    VData("Ellipse", [center, VInt(width), VInt(height)]) -> {
      use p <- result.try(to_point(center))
      use w <- result.try(dimension(width))
      use h <- result.try(dimension(height))
      Ok(Ellipse(p, w, h))
    }

    _ ->
      Error(BadDrawing(
        "expected Line, Circle, Square, Rectangle, or Ellipse with valid fields",
      ))
  }
}

fn dimension(n: Int) -> Result(Float, EvalError) {
  case n >= 0 {
    True -> Ok(int.to_float(n))
    False -> Error(BadDrawing("shape dimensions must be nonnegative"))
  }
}

fn to_point(v: Value) -> Result(Point, EvalError) {
  case v {
    VData("Point", [VInt(x), VInt(y)]) ->
      Ok(Point(int.to_float(x), int.to_float(y)))

    _ -> Error(BadDrawing("expected a Point"))
  }
}
