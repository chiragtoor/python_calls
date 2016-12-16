import glob
import sys
sys.path.append('gen-py')

from geo import GeoService
from geo.ttypes import Point, Boundary

from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
from thrift.server import TServer

from shapely.geometry import Polygon

class GeoServiceHandler:

    def blockInZone(self, block, zone):
        # need to switch the order of lat and lng in order to get correct results
        boundaryPoints = []
        for boundaryPoint in zone.points:
            boundaryPoints.append((boundaryPoint.lng, boundaryPoint.lat))
        # create a polygon from the zone definition
        zonePolygon = Polygon(boundaryPoints)

        boundaryPoints = []
        for boundaryPoint in block.points:
            boundaryPoints.append((boundaryPoint.lng, boundaryPoint.lat))
        # create a polygon from the block definition
        blockPolygon = Polygon(boundaryPoints)
        # use shapely to detect a polygon intersection between the two
        return blockPolygon.intersects(zonePolygon)

if __name__ == '__main__':
    handler = GeoServiceHandler()
    processor = GeoService.Processor(handler)
    transport = TSocket.TServerSocket(port=9090)
    tfactory = TTransport.TFramedTransportFactory()
    pfactory = TBinaryProtocol.TBinaryProtocolFactory()

    server = TServer.TSimpleServer(processor, transport, tfactory, pfactory)
    print 'Serving ...'
    server.serve()