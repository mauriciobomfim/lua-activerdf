local UUID = require 'uuid'
local re = require 're'
local table = table
local string = string
local RDFS = activerdf.RDFS
local Literal = activerdf.Literal

local nonspace = re.compile("[^ \t\b\r\f\v]")
local space = re.compile("[ \t\b\r\f\v]")
local _literal = re.compile( [[ { '"' ('\\"' / [^"])* '"' ('^^'%nonspace+)? } ]] , { nonspace = nonspace } )
local _bnode = re.compile ( [[ { '_:' %nonspace* } ]] , { nonspace = nonspace } )
local _resource = re.compile ( [[ {'<'[^>]*'>'} ]] )

-- constants for extracting resources/literals from sql results
local MatchNode = re.compile ([[ %l / %bn / %r ]], { l = _literal, bn = _bnode , r = _resource })
local MatchBNode = re.compile ( [[ '_:' { %nonspace* } ]] , { nonspace = nonspace } )
local MatchResource = re.compile ( [[ '<' { [^>]* } '>' ]] )
local MatchLiteral = re.compile( [[ '"' { ('\\"' / [^"])* } '"' ('^^<' { (!'>' %nonspace)+ } '>')? ]] , { nonspace = nonspace } )

---------------------------------------------------------------------
--- Ntriples parser
-- @release $Id$
---------------------------------------------------------------------																					 																				    
module "activerdf.NTriplesParser"

-- 
function parse_node(input)
	local capture
	local capture2
	local value	
	capture = MatchBNode:match(input)
	if capture then
		return RDFS.Resource("http://www.activerdf.org/bnode/"..UUID.new().."/#"..capture)		
	else
		capture, capture2 = MatchLiteral:match(input)		
		if capture then
			value = fix_unicode(capture)
			if capture2 then
				return Literal.typed(value, RDFS.Resource(capture2))
			else
				return value
			end
		else
			capture = MatchResource:match(input)
			if capture then
				return RDFS.Resource(capture)
			else
				return nil
			end
		end
	end
end

--- parses an input string of ntriples and returns a nested table of { s, p, o }
-- (which are in turn ActiveRDF objects).
-- @param input string of ntriples
function parse(input)
	-- need unique identifier for this batch of triples (to detect occurence of 
	-- same bnodes _:#1
	local uuid = UUID.new()
	local nodes		
	local subject
	local predicate
	local object
	local value
	local capture, capture2
	local result = {}
	
	for triple in input:gmatch("[^\r\n]+") do	    		
		nodes = {}		
     	triple = triple:match("%s*(.*)")
		while triple and triple ~= "" do
			
			local _triple = MatchNode:match(triple)
			
			table.insert(nodes, _triple)
		
			if table.getn(nodes) == 3 then
				break
			end
			
			triple = triple:match( "%s*" .. _triple:gsub("([[%]$()%%.*+?^-])", "%%%1") .. "(.*)" )
							
			if triple then
				triple = triple:match("%s*(.*)")
			end
      	end
      	
		-- handle bnodes if necessary (bnodes need to have uri generated)
		capture = MatchBNode:match(nodes[1])
		if capture then
			subject = RDFS.Resource("http://www.activerdf.org/bnode/"..uuid.."/#"..capture)
		else
			capture = MatchResource:match(nodes[1])
			if capture then
				subject = RDFS.Resource(capture)
			end
		end
		
		capture = MatchResource:match(nodes[2])
      	if capture then
			predicate = RDFS.Resource(capture)
      	end

		-- handle bnodes and literals if necessary (literals need unicode fixing)
		capture = MatchBNode:match(nodes[3])
		if capture then
			object = RDFS.Resource("http://www.activerdf.org/bnode/"..uuid.."/#"..capture)
		else
			capture, capture2 = MatchLiteral:match(nodes[3])			
			if capture then
				value = fix_unicode(capture)
            if capture2 then
					object = Literal.typed(value, RDFS.Resource(capture2))
            else
					object = value
            end
			else
				capture = MatchResource:match(nodes[3])
				if capture then               
					object = RDFS.Resource(capture)
				end
			end
		end

      -- collect s, p, o into array to be returned
		table.insert(result, { subject, predicate, object })
	end
	return result
end

	

--- fixes unicode characters in literals (because we parse them wrongly somehow).
function fix_unicode(str)
	--tmp = str.gsub(/\\\u([0-9a-fA-F]{4,4})/u){ "U+#$1" }
    --tmp.gsub(/U\+([0-9a-fA-F]{4,4})/u){["#$1".hex ].pack('U*')}
	return str
end
