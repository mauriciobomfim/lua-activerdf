require 'activerdf'
require "activerdf.test.common"

local ConnectionPool = activerdf.ConnectionPool
local XSD = activerdf.XSD
local LocalizedString = activerdf.LocalizedString
local Literal = activerdf.Literal

local function dotest(test)
	setup()
	test()
	teardown()
end

-- TestLiteral
local adapter

function setup()
	ConnectionPool.clear()
	adapter = get_adapter()
end

function teardown()
end

function test_xsd_string()
	local test = Literal.typed('test', XSD.string)
	assert ( '"test"^^<http://www.w3.org/2001/XMLSchema#string>' == test:to_ntriple() )
end

function test_automatic_conversion()
	-- infer string
	local test = 'test'
	assert ( '"test"^^<http://www.w3.org/2001/XMLSchema#string>' == test:to_ntriple() )

	-- infer integer
	test = 18
	assert ( '"18"^^<http://www.w3.org/2001/XMLSchema#integer>' == Literal.to_ntriple(test) )

	-- infer boolean
	test = true
	assert ( '"true"^^<http://www.w3.org/2001/XMLSchema#boolean>' == Literal.to_ntriple(test) )
end
  
function test_equality()
	local test1 = 'test'
	local test2 = Literal.typed('test', XSD.string)  
	assert ( test2:to_ntriple() == test1:to_ntriple() )
end
  
function test_language_tag()
	local cat = 'cat'
	local cat_en = LocalizedString('cat', '@en')
	assert ( '"cat"@en' == cat_en:to_ntriple() )
	assert ( cat:to_ntriple() ~= cat_en:to_ntriple() )
	assert ( '"dog"@en-GB' == LocalizedString('dog', '@en-GB'):to_ntriple() )
	assert ( '"dog"@en@test' == LocalizedString('dog', '@en@test'):to_ntriple() )
end

dotest(test_automatic_conversion)
dotest(test_equality)
dotest(test_language_tag)
dotest(test_xsd_string)