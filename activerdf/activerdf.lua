---------------------------------------------------------------------
-- Lua ActiveRDF is a library for accessing RDF data from Lua programs. In fact, Lua ActiveRDF is a Lua version of ActiveRDF (www.activerdf.org) for Ruby.<br><br>
-- Lua ActiveRDF allows you to rapidly create semantic web applications.<br><br>
-- Lua ActiveRDF gives you a Domain Specific Language (DSL) for your RDF model: you can 
-- address RDF resources, classes, properties, etc. programmatically, without queries.<br>
-- <br>
-- Lua ActiveRDF uses the module loop.simple (<a href="http://loop.luaforge.net">http://loop.luaforge.net</a>) 
-- to simulate class-based object-oriented programming. 
-- The <a href="http://loop.luaforge.net/manual/models.html">API</a> of loop.simple is available as the module <code><b>activerdf.oo</b></code>.<br>
-- 
-- <h2>Simple Example</h2>
-- The following example uses a SPARQL endpoint and displays all 
-- people found in the data source:
-- <pre class = 'example'>
--	rdf = require 'activerdf'<br>
--	url = 'http://tecweb08.tecweb.inf.puc-rio.br:8890/sparql'<br>
--	rdf.ConnectionPool.add_data_source { type = 'sparql', engine = 'virtuoso', url = url }<br>
--	<br>
--	foaf = rdf.Namespace.register ( 'test', 'http://activerdf.luaforge.net/test/' )<br>
--	<br>
--	people = foaf.Person:find_all()<br>
--	for _, person in ipairs(people) do<br>
--	&#09;print(person.name)<br>
--	end
-- </pre>
-- <p>
-- Lua ActiveRDF is distributed as a Lua module.<br>
-- <br>
-- Lua ActiveRDF is free software and uses the same license as Lua 5.1.<br>
-- <br>
-- Current version is 0.1. It was developed for Lua 5.1. <a href="http://luaforge.net/frs/?group_id=370">Download</a>
-- <br><br>
-- Website: <a href="http://activerdf.luaforge.net">http://activerdf.luaforge.net</a><br>
-- @release $Id$
-- </p>  
---------------------------------------------------------------------
local require = require

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