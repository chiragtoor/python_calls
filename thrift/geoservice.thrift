namespace py geo

struct Point {
  1: double lat,
  2: double lng
}

struct Boundary {
  2: list<Point> points
}

service GeoService {

  bool blockInZone(1:Boundary block, 2:Boundary zone)

}