require 'activerdf'
require 'activerdf.test.common'

local oo = activerdf.oo
local ConnectionPool = activerdf.ConnectionPool
local ActiveRdfAdapter = activerdf.ActiveRdfAdapter
local table = activerdf.table

local function dotest(test)
	setup()
	test()
	teardown()
end

-- TestConnectionPool 
function setup()
	ConnectionPool.clear()
end

function teardown()
	ConnectionPool.clear()
end

function test_class_add_data_source()
	-- test for successfull adding of an adapter
	local adapter = get_adapter()	
	assert ( oo.instanceof (adapter, ActiveRdfAdapter) )
	assert ( table.include(ConnectionPool.adapter_pool, adapter) )

	-- now check that we get the same adapter if we supply the same parameters
	local adapter2 = get_adapter()
	assert ( adapter == adapter2 )
	-- test same object_id
end

function test_class_adapter_pool()	
	assert ( 0 == table.getn(ConnectionPool.adapter_pool) )
	local adapter = get_adapter()
	assert ( 1 == table.getn( ConnectionPool.adapter_pool) )
end

function test_class_register_adapter()
	ConnectionPool.register_adapter('funkytype', ActiveRdfAdapter)
	assert ( table.include(ConnectionPool.adapter_types(), 'funkytype') )
end

function test_class_auto_flush_equals()
	-- assert auto flushing by default
	assert ( ConnectionPool.auto_flush )
	ConnectionPool.auto_flush = false
	assert ( not ConnectionPool.auto_flush )
end

function test_class_clear()
	ConnectionPool.clear()
	assert ( table.empty ( ConnectionPool.adapter_pool ) )
	assert ( ConnectionPool.write_adapter == nil )
end

function test_class_write_adapter()
	local adapter = get_write_adapter()
	assert ( oo.instanceof(  adapter, ActiveRdfAdapter ) )
end

function test_class_write_adapter_equals()
	local adapter1 = get_write_adapter()
	local adapter2 = get_different_write_adapter(adapter1)
	assert ( adapter2 == ConnectionPool.write_adapter )
	ConnectionPool.write_adapter = adapter1
	assert ( adapter1 == ConnectionPool.write_adapter )
end

dotest(test_class_adapter_pool)	
dotest(test_class_add_data_source)	
dotest(test_class_auto_flush_equals)	
dotest(test_class_clear)
dotest(test_class_register_adapter)
dotest(test_class_write_adapter)
dotest(test_class_write_adapter_equals)