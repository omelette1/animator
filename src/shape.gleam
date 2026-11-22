//// Geometry used by the animator.

pub type Point {
  Point(x: Float, y: Float)
}

pub type Shape {
  Line(start: Point, end: Point)
  Circle(center: Point, radius: Float)
  Square(center: Point, size: Float)
  Rectangle(center: Point, width: Float, height: Float)
  Ellipse(center: Point, width: Float, height: Float)
}

pub type Path {
  Path(shape: Shape, start: Float, end: Float, thickness: Float)
}
