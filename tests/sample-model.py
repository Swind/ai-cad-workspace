from cad import xbf
import build123d as bd


@xbf("plate.xbf")
def plate():
    return bd.Box(80, 50, 5) - bd.Cylinder(3, 7)


if __name__ == "__main__":
    plate()
