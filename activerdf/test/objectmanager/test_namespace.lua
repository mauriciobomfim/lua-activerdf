require 'activerdf'
require 'activerdf.objectmanager.namespace'
require 'activerdf.test.common'

local oo = require 'loop.simple'
local RDFS = activerdf.RDFS
local RDF = activerdf.RDF
local Namespace = activerdf.Namespace

-- TestNamespace
local Rdf = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
local Rdfs = 'http://www.w3.org/2000/01/rdf-schema#'
local RdfType = RDFS.Resource('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
local RdfsResource = RDFS.Resource('http://www.w3.org/2000/01/rdf-schema#Resource')

function test_default_ns_expansion()
	local rdftype = RdfType
	local rdfsresource = RdfsResource

	assert ( rdftype == RDF.type )
	assert ( rdftype == Namespace.lookup('rdf', 'type') )
	
	assert ( rdfsresource == RDFS.Resource )
	assert ( rdfsresource == Namespace.lookup('rdfs', 'Resource') )
end

function test_registration_of_rdf_and_rdfs()
	local rdftype = RDFS.Resource(RdfType)
	local rdfsresource = RDFS.Resource(RdfsResource)

	assert ( rdftype == RDF.type )
	assert ( rdfsresource == RDFS.Resource )
end

function test_find_prefix()
	assert ( 'rdf' == Namespace.prefix(Namespace.lookup('rdf', 'type')) )
	assert ( 'rdf' == Namespace.prefix(Namespace.expand('rdf', 'type')) )

	assert ( 'rdfs' == Namespace.prefix(Namespace.lookup('rdfs', 'Resource')) )
	assert ( 'rdfs' == Namespace.prefix(Namespace.expand('rdfs', 'Resource')) )
end

function test_class_localname()
	assert ( 'type' == Namespace.lookup('rdf', 'type'):localname() )
	assert ( 'type' == RDF.type:localname() )

	assert ( 'Class' == Namespace.lookup('rdfs', 'Class'):localname() )
	assert ( 'Class' == RDFS.Class:localname() )
end

function test_class_register()
	local test = 'http://test.org/'
	local abc = RDFS.Resource(test.."abc")
	Namespace.register ( 'test', test )

	assert ( abc == Namespace.lookup('test', 'abc') )
	assert ( abc == activerdf.TEST.abc )
end

function test_attributes()		
	assert ( pcall ( function() return assert ( activerdf.RDFS.domain ) end ) )
	assert ( pcall ( function() return assert ( activerdf.RDF.type ) end ) )
	assert ( not pcall ( function() return assert ( activerdf.FOAF.type ) end ) )

	local foaf = 'http://xmlns.com/foaf/0.1/'
	activerdf.Namespace.register ( 'foaf', foaf )

	local foafname = activerdf.RDFS.Resource(foaf..'name')
	assert ( foafname == activerdf.FOAF.name )
end

test_attributes()
test_class_localname()
test_class_register()
test_default_ns_expansion()
test_find_prefix()
test_registration_of_rdf_and_rdfs()