-- ActiveRDF loader

activerdf = {}
activerdf.oo = require 'loop.simple'

-- load standard classes that need to be loaded at startup
require 'activerdf.table'
require 'activerdf.string'
require 'activerdf.objectmanager.resource'
require 'activerdf.objectmanager.bnode'
require 'activerdf.objectmanager.literal'
require 'activerdf.federation.activerdf_adapter'


local load_adapter = function(s)
  require(s)
end

load_adapter('activerdf_sparql')
load_adapter('activerdf_rdflite')