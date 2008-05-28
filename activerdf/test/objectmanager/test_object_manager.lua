require 'activerdf'
require 'activerdf.test.common'

local oo = require 'loop.simple'
local ConnectionPool = activerdf.ConnectionPool
local RDFS = activerdf.RDFS
local Namespace = activerdf.Namespace

-- TestObjectManager
function setup()
	ConnectionPool.clear()
end

function teardown()
end

function test_resource_creation()
	assert ( pcall ( RDFS.Resource, 'abc' ) )

	local r1 = RDFS.Resource('abc')
	local r2 = RDFS.Resource('cde')
	local r3 = RDFS.Resource('cde')
	assert ( r3 == RDFS.Resource(r3) )
	assert ( r3 == RDFS.Resource( tostring( r3 ) ) )

	assert ( 'abc' == r1.uri )
	assert ( 'cde' == r2.uri )
	assert ( r3 == r2 )
end

function test_class_construct_classes()
	local adapter = get_write_adapter()
	adapter:load ( "test_person_data.nt" )

	Namespace.register('test', 'http://activerdf.org/test/')

	assert ( RDFS.Resource('http://activerdf.org/test/Person') == activerdf.TEST.Person )
	assert ( oo.isclass ( activerdf.TEST.Person ) )
	-- assert TEST::Person.ancestors.include?(RDFS::Resource) -- to check ancestors on loop
	assert ( oo.superclass ( activerdf.TEST.Person ) == activerdf.RDFS.Resource )
	assert ( oo.instanceof ( activerdf.TEST.Person(''), activerdf.TEST.Person ) )
	assert ( pcall ( activerdf.TEST.Person('').uri ) )

	assert ( RDFS.Resource('http://www.w3.org/2000/01/rdf-schema#Class') == RDFS.Class )
	-- assert RDFS::Class.ancestors.include?(RDFS::Resource)
	assert ( oo.superclass ( RDFS.Class ) == RDFS.Resource )
	assert ( oo.isclass ( RDFS.Class ) )
	assert ( oo.instanceof ( RDFS.Class(''), RDFS.Resource ) )
	assert ( pcall ( RDFS.Class('').uri ) )
end

function test_custom_code()
	Namespace.register('test', 'http://activerdf.org/test/')

	activerdf.TEST.Person.hello = function() return 'world' end
	assert ( pcall ( activerdf.TEST.Person('').hello ) )
	assert ( 'world' ==  activerdf.TEST.Person('').hello() )
end

function test_class_uri()
	local adapter = get_write_adapter()
	adapter:load ( "test_person_data.nt" )
	Namespace.register('test', 'http://activerdf.org/test/')

	assert ( RDFS.Resource('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') == RDF.type )
	assert ( RDF.type == RDFS.Resource('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') )
	assert ( activerdf.TEST.Person == RDFS.Resource('http://activerdf.org/test/Person') )
	assert ( RDFS.Resource('http://activerdf.org/test/Person') == activerdf.TEST.Person )
end

function test_to_xml()
	get_adapter():load ( "test_person_data.nt" )
	Namespace.register('test', 'http://activerdf.org/test/')

	local eyal = RDFS.Resource('http://activerdf.org/test/eyal')
	eyal.age = 29
	assert ( 29 == eyal.age )
	local snippet = [[<rdf:Description rdf:about="#eyal">
	<test:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">29</test:age>
	<test:eye rdf:datatype="http://www.w3.org/2001/XMLSchema#string">blue</test:eye>
	<rdf:type rdf:resource="http://activerdf.org/test/Person"/>
	<rdf:type rdf:resource="http://www.w3.org/2000/01/rdf-schema#Resource"/>
	</rdf:Description>
	</rdf:RDF>]]
	assert ( string.find ( eyal:to_xml(), snippet ) )


	local url = 'http://gollem.swi.psy.uva.nl/cgi-bin/rdf-parser'
	--uri = URI.parse(url)
	--req = Net::HTTP::Post.new(url)
	--req.set_form_data('rdf' => eyal.to_xml)
	--res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(req) }
	--assert_match /RDF statement parsed successfully/, res.body, "SWI-Prolog failed to parse XML output"
end

setup()
--test_class_construct_classes()
--test_class_uri()
test_custom_code()
test_resource_creation()
--test_to_xml()
teardown()