# From: https://amat.readthedocs.io/en/master/examples/example-02-atmosphere.html

import AMAT
import os
from AMAT.planet import Planet

planet = Planet("VENUS")
atmdata_dir = os.path.join(os.path.dirname(AMAT.__file__), "atmdata")
planet.loadAtmosphereModel(os.path.join(atmdata_dir, 'Venus/venus-gram-avg.dat'), 0, 1, 2, 3)

print("Venus scaleHeight:", planet.scaleHeight(0, planet.density_int))
