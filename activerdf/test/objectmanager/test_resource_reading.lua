require 'activerdf'
require 'activerdf.federation.connection_pool'
require "activerdf.test.common"

local ConnectionPool = activerdf.ConnectionPool
local Namespace = activerdf.Namespace
local RDFS = activerdf.RDFS
local adapter
local yeal

local TEST_PATH = 'lua/activerdf/test/'

-- TestResourceReading
function setup()
	ConnectionPool.clear()
	adapter = get_adapter()
	adapter:load ( TEST_PATH .. "test_person_data.nt" )
	Namespace.register('test', 'http://activerdf.org/test/')
	
	eyal = RDFS.Resource ( 'http://activerdf.org/test/eyal' )
end

function teardown()
end

function test_find_all_instances()
	assert ( 7 == table.getn( RDFS.Resource:find_all() ) )
	assert ( activerdf.table.equals ( { activerdf.TEST.eyal, activerdf.TEST.other }, activerdf.TEST.Person:find_all() ) )
end

function test_class_predicates()
	assert ( 4 == table.getn( RDFS.Resource.predicates() ) )
end

function test_eyal_predicates()
	-- assert that eyal's three direct predicates are eye, age, and type
	local preds = activerdf.table.map ( eyal:direct_predicates(), function(i,p) return p.uri end )
	assert ( 3 == table.getn ( preds ) )
	table.foreach ( {'age', 'eye', 'type'}, function(i,pr) 
		assert ( table.any ( preds, function(i, uri) return string.find(uri, ".*"..pr.."$") end ), "Eyal should have predicate "..pr )														  
	end)

	-- test class level predicates
	local class_preds = table.map ( eyal:class_level_predicates(), function(i,p) return p.uri end )
	-- eyal.type: person and resource, has predicates age, eye
	-- not default rdfs:label, rdfs:comment, etc. because not using rdfs reasoning
	assert ( 4 == table.getn ( class_preds ) )
end

function test_eyal_types()
	local types = eyal:type()
	assert ( 2 == table.getn ( types ) )
	assert ( table.include ( types, activerdf.TEST.Person ) )
	assert ( table.include ( types, activerdf.RDFS.Resource) )
end

function test_eyal_age()
	-- triple exists '<eyal> age 27'
	assert ( 27 == eyal.age )
	assert ( 27 == eyal.test.age ) -- verify
	assert ( activerdf.table.equals ( {27} , eyal:all_age() ) )

	-- Person has property car, but eyal has no value for it
	assert ( nil == eyal.car )
	assert ( nil == eyal.test.car )
	assert ( activerdf.table.equals ( {}, eyal:all_test().car ) )

	-- non-existent method should throw error
	assert ( nil == eyal.non_existing_method )
end

function test_eyal_type()
	assert ( oo.instance_of ( eyal, RDFS.Resource ) )
	assert ( oo.instance_of ( eyal, activerdf.TEST.Person ) )
end

function test_find_options()
	local all = { Namespace.lookup('test','Person'), Namespace.lookup('rdfs', 'Class'), Namespace.lookup('rdf', 'Property'), eyal, activerdf.TEST.car, activerdf.TEST.age, activerdf.TEST.eye }
	local found = RDFS.Resource:find()
	table.sort(all)
	table.sort(found)
	assert ( activerdf.table.equals ( all, found ) )

	local properties = { activerdf.TEST.car, activerdf.TEST.age, activerdf.TEST.eye }
	found = RDFS.Resource:find( { where = { [RDFS.domain] = RDFS.Resource } } )
	
	table.sort(properties)
	table.sort(found)	
	assert ( activerdf.table.equals ( properties, found ) )

	found = RDFS.Resource:find( { where = { [RDFS.domain] = RDFS.Resource, prop = 'any'} } )
	table.sort(found)	
	assert ( activerdf.table.equals ( properties, found ) )

	found = activerdf.TEST.Person:find( { order = activerdf.TEST.age } )
	assert ( activerdf.table.equals ( { activerdf.TEST.other, activerdf.TEST.eyal }, found ) )
end

function test_find_methods()
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_eye('blue') ) )
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_test():eye('blue') ) )

	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_age(27) ) )
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_test():age(27) ) )

	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_age_and_eye(27, 'blue') ) )
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_test():age_and_test():eye(27, 'blue') ) )
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_test():age_and_eye(27, 'blue') ) )
	assert ( activerdf.table.equals ( {eyal}, RDFS.Resource:find_by_age_and_test():eye(27, 'blue') ) )
end

-- test for writing if no write adapter is defined (like only sparqls)
function test_write_without_write_adapter()
	ConnectionPool.clear()
	get_read_only_adapter()
	assert ( not pcall ( loadstring ( "eyal.test.age = 18") ) )
end

function test_finders_with_options()
	ConnectionPool.clear()
	local adapter = get_adapter
	local file_one = TEST_PATH .. "small-one.nt"
	local file_two = TEST_PATH .. "small-two.nt"
	adapter:load ( file_one )
	adapter:load ( file_two )

	local one = RDFS.Resource("file:"..file_one)
	local two = RDFS.Resource("file:"..file_two)

	assert ( 2 == table.getn ( RDFS.Resource:find() ) )
	assert ( 2 == table.getn ( RDFS.Resource:find( '?all' ) ) )
	assert ( 2 == table.getn ( RDFS.Resource:find( '?all', { limit = 10 } ) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find( '?all', { limit = 1 } ) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find( '?all', { context = one } ) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find( '?all', { context = one, limit = 1 } ) ) )
	assert ( 0 == table.getn ( RDFS.Resource:find( '?all', { context = one, limit = 0 } ) ) )

	assert ( 1 == table.getn ( RDFS.Resource:find_by_eye( 'blue' ) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find_by_eye( 'blue', { context = one } ) ) )
	assert ( 0 == table.getn ( RDFS.Resource:find_by_eye( 'blue', { context = two } ) ) )

	assert ( 2 == table.getn ( RDFS.Resource:find_by_rdf():type(RDFS.Resource) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find_by_rdf():type(RDFS.Resource, { context = one } ) ) )
	assert ( 1 == table.getn ( RDFS.Resource:find_by_eye_and_rdf():type('blue', RDFS.Resource, { context = one } ) ) )
end

setup()
test_class_predicates()
test_eyal_age()
--test_eyal_predicates()
--test_eyal_type()
--test_eyal_types()
--test_find_all_instances()
--test_find_methods()
--test_find_options()
--test_finders_with_options()
--test_write_without_write_adapter()
teardown()