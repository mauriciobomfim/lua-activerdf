require 'activerdf'
require 'activerdf.federation.federation_manager'
require 'activerdf.queryengine.query'
require 'activerdf.test.common'

local ConnectionPool = activerdf.ConnectionPool
local Namespace = activerdf.Namespace

local function dotest(test)
	setup()
	test()
	teardown()
end

local TEST_PATH = 'lua/activerdf/test/'

-- TestAdapter
function setup()
	ConnectionPool.clear()
end

function teardown()

end

function test_ensure_adapter_behaviour()
	local read_adapters = get_all_read_adapters()
	local write_adapters = get_all_write_adapters()
	local read_behaviour = { 'query', 'translate', 'writes', 'reads' }
	local write_behaviour = { 'add', 'delete', 'flush', 'load' }

	table.foreach(read_behaviour, function(i, method)
		table.foreach(read_adapters, function(i, a)
			assert ( a[method] ~= nil , "adapter "..a.class.." should respond to "..method )
		end)
	end)

	table.foreach(write_behaviour, function(i, method)
		table.foreach(write_adapters, function(i, a)
			assert ( a[method] ~= nil , "adapter #{a.class} should respond to #{method}" )
		end)
	end)
end

function test_update_value()
	local adapter = get_write_adapter()
	adapter:load ( TEST_PATH .. "test_person_data.nt")

	Namespace.register('test', 'http://activerdf.org/test/')
	local eyal = Namespace.lookup('test', 'eyal')

	assert ( 1 == table.getn(eyal.all_age) )
	assert ( 27 == eyal.age )

	-- << doesn't work on Fixnums
	--eyal.age << 30
	--assert_equal 1, eyal.all_age.size
	--assert !eyal.all_age.include?(30)
	--assert eyal.all_age.include?(27)

	eyal.age = 40
	assert ( 1 == table.getn(eyal.all_age) )
	assert ( eyal.age == 40 )
end

dotest(test_ensure_adapter_behaviour)
dotest(test_update_value)
