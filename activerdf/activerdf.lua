---------------------------------------------------------------------
-- Lua ActiveRDF is a library for accessing RDF data from Lua programs. In fact, Lua ActiveRDF is a Lua version of ActiveRDF (www.activerdf.org) for Ruby.<br><br>
-- Lua ActiveRDF allows you to rapidly create semantic web applications.<br><br>
-- Lua ActiveRDF gives you a Domain Specific Language (DSL) for your RDF model: you can 
-- address RDF resources, classes, properties, etc. programmatically, without queries.<br>
-- @release $Id$
-- <br><br><br><br><br><br><br><br><br><br><br><br>
---------------------------------------------------------------------
module 'activerdf'

oo = require 'loop.simple'

-- load standard classes that need to be loaded at startup
require 'activerdf.table'
require 'activerdf.string'
require 'activerdf.objectmanager.resource'
require 'activerdf.objectmanager.bnode'
require 'activerdf.objectmanager.literal'
require 'activerdf.federation.activerdf_adapter'

local function load_adapter (adapter)
  require(adapter)
end

load_adapter('activerdf_sparql')
load_adapter('activerdf_rdflite')