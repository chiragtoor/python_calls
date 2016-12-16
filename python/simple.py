from shapely.geometry import Polygon, Point

def blockInZone(block, zone):
  boundaryPoints = []
  for pair in block:
    boundaryPoints.append((pair[1], pair[0]))
  blockPolygon = Polygon(boundaryPoints)

  boundaryPoints = []
  for pair in zone:
    boundaryPoints.append((pair[1], pair[0]))
  zonePolygon = Polygon(boundaryPoints)

  return blockPolygon.intersects(zonePolygon)