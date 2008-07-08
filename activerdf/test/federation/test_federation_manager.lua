require 'activerdf'
require 'activerdf.federation.federation_manager'
require 'activerdf.test.common'

local ConnectionPool = activerdf.ConnectionPool
local RDFS = activerdf.RDFS
local FederationManager = activerdf.FederationManager
local Query = activerdf.Query
local table = activerdf.table

local function dotest(test)
	setup()
	test()
	teardown()
end

-- TestFederationManager
function setup()
	ConnectionPool.clear()
end

function teardown()

end

local eyal = RDFS.Resource("http://activerdf.org/test/eyal")
local age = RDFS.Resource("http://activerdf.org/test/age")
local age_number = RDFS.Resource("27")
local eye = RDFS.Resource("http://activerdf.org/test/eye")
local eye_value = RDFS.Resource("blue")
local type = RDFS.Resource("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
local person = RDFS.Resource("http://www.w3.org/2000/01/rdf-schema#Resource")
local resource = RDFS.Resource("http://activerdf.org/test/Person")

function test_single_pool()
	local a1 = get_adapter()
	local a2 = get_adapter()
	assert ( a1 == a2 )
	-- assert ( a1.object_id == a2.object_id )
end

function test_class_add()
	local write1 = get_write_adapter()
	FederationManager.add(eyal, age, age_number)

	local age_result = Query():select('?o'):where(eyal, age, '?o'):execute()[1]
	assert ("27" == age_result)
end

function test_class_add_no_write_adapter()
 -- zero write, one read -> must raise error
 local adapter = get_read_only_adapter()
 assert ( not adapter.writes )
 assert ( not pcall(FederationManager.add, eyal, age, age_number) ) 
end

function test_class_add_one_write_one_read()
	-- one write, one read

	local write1 = get_write_adapter()
	local read1 = get_read_only_adapter()
	assert ( write1 ~= read1 )
	-- assert ( write1.object_id ~= read1.object_id )

	FederationManager.add(eyal, age, age_number)

	local age_result = Query():select('?o'):where(eyal, age, '?o'):execute()
	assert ( "27" == age_result )
	
end

function test_get_different_read_and_write_adapters()
	local r1 = get_adapter()
	local r2 = get_different_adapter(r1)
	assert ( r1 ~= r2 )
	-- assert ( r1.object_id ~= r2.object_id )

	local w1 = get_write_adapter()
	local w2 = get_different_write_adapter(w1)
	assert ( w1 ~= w2 )
	-- assert ( w1.object_id ~= w2.object_id )
end

function test_class_add_two_write()
	-- two write, one read, no switching
	-- we need to different write adapters for this
	
	local write1 = get_write_adapter()
	local write2 = get_different_write_adapter(write1)

	local read1 = get_read_only_adapter()

	FederationManager.add(eyal, age, age_number)

	local age_result = Query():select('?o'):where(eyal, age, '?o'):execute()
	assert ( "27" == age_result )
end

function test_class_add_two_write_switching()
	-- two write, one read, with switching

	local write1 = get_write_adapter()
	local write2 = get_different_write_adapter(write1)

	local read1 = get_read_only_adapter()

	FederationManager.add(eyal, age, age_number)
	local age_result = Query():select('?o'):where(eyal, age, '?o'):execute()
	assert ( "27" == age_result )

	ConnectionPool.write_adapter = write2

	FederationManager.add(eyal, eye, eye_value)
	age_result = Query():select('?o'):where(eyal, eye, '?o'):execute()
	assert ( "blue" == age_result )

	local second_result = write2:query(Query():select('?o'):where(eyal, eye, '?o'))
	assert ( "blue" == second_result )
end

-- this test makes no sense without two different data sources
function test_federated_query()
	local first_adapter = get_write_adapter()
	first_adapter.load("lua/activerdf/test/test_person_data.nt")
	local first = Query():select('?s','?p','?o'):where('?s','?p','?o'):execute()

	-- results should not be empty, because then the test succeeds trivially
	assert ( first ~= nil )
	assert ( not table.equals(first, {}) )

	ConnectionPool.clear()
	local second_adapter = get_different_write_adapter(first_adapter)
	second_adapter.load("lua/activerdf/test/test_person_data.nt")
	second = Query():select('?s','?p','?o'):where('?s','?p','?o'):execute()

	-- now we query both adapters in parallel
	ConnectionPool.clear()
	first_adapter = get_write_adapter()
	first_adapter.load("lua/activerdf/test/test_person_data.nt")
	second_adapter = get_different_write_adapter(first_adapter)
	second_adapter.load("lua/activerdf/test/test_person_data.nt")
	local both = Query():select('?s','?p','?o'):where('?s','?p','?o'):execute()
	-- assert both together contain twice the sum of the separate sources
	assert ( table.equals(table.add(first, second),  both) )

	-- since both sources contain the same data, we check that querying (both!)
	-- in parallel for distinct data, actually gives same results as querying
	-- only the one set
	local uniq = Query():distinct('?s','?p','?o'):where('?s','?p','?o'):execute()
	assert ( first == uniq )
end

test_class_add()
dotest(test_class_add_no_write_adapter)
--test_class_add_one_write_one_read()
--test_class_add_two_write()
--test_class_add_two_write_switching()
--test_federated_query()
--test_get_different_read_and_write_adapters()
dotest(test_single_pool)