require 'activerdf'
require 'activerdf.queryengine.ntriples_parser'

local luasql = require 'luasql.sqlite3'

local oo = activerdf.oo
local table = activerdf.table
local string = string
local tostring = tostring
local URI = require 'uri'
local re = require 're'
local RDFS = activerdf.RDFS
local NTriplesParser = activerdf.NTriplesParser
local Namespace = activerdf.Namespace
local Query = activerdf.Query
local ConnectionPool = activerdf.ConnectionPool
local ObjectManager = activerdf.ObjectManager
local ActiveRdfAdapter = activerdf.ActiveRdfAdapter
local io = io
local string = string
local type = type
local unpack = unpack
local error = error
local tonumber = tonumber
local math = math
local next = next
local ipairs = ipairs

--$activerdflog.info "loading RDFLite adapter"

--begin 
--	require 'ferret'
--	@@have_ferret = true
--rescue LoadError
--	$activerdflog.info "Keyword search is disabled since we could not load Ferret. To 
--	enable, please do \"gem install ferret\""
--	@@have_ferret = false
--end

local Resource = re.compile ( [[ '<' { [^>]* } '>' ]] )
local Literal = re.compile( [[ '"' { ('\\"' / [^"])* } '"' ]]  )
local SPOC = {'s','p','o','c'}


local spoc_index = function(index)	
	return math.fmod ( index - 1, 4 ) + 1
end

local alias_number = function(index)	
	return math.floor ( ( index - 1 ) / 4 )
end
-----------------------------------------------------------------------------
-- Prepares a SQL statement using placeholders.
-- Extracted from http://sputnik.freewisdom.org
-----------------------------------------------------------------------------
local function prepare(statement, ...)
	local count = select('#', ...)

	if count > 0 then
		local someBindings = {}

		for index = 1, count do
			local value = select(index, ...)
			local type = type(value)

			if type == 'string' then
				value = '\'' .. value:gsub('\'', '\'\'') .. '\''
			elseif type == 'nil' then
				value = 'null'
			else
				value = tostring(value)
			end

			someBindings[index] = value
		end
		
		statement = statement:format(unpack(someBindings))
	end

	return statement
end


-- RDFLite is a lightweight RDF database on top of sqlite3. It can act as adapter 
-- in ActiveRDF. It supports on-disk and in-memory usage, and allows keyword 
-- search if ferret is installed.
module "activerdf_rdflite"

RDFLite = oo.class({}, ActiveRdfAdapter)

ConnectionPool.register_adapter('rdflite', RDFLite)

-- bool_accessor :keyword_search, :reasoning

-- instantiates RDFLite database
-- available parameters:
-- * :location => filepath (defaults to memory)
-- * :keyword => true/false (defaults to false)
-- * :pidx, :oidx, etc. => true/false (enable/disable these indices)

function RDFLite:__init(params)
	local params = params or {}
	
	--$activerdflog.info "initialised rdflite with params #{params.to_s}"

	-- if no file-location given, we use in-memory store
	local file = params['location'] or ':memory:'
	local dbenv = luasql.sqlite3()
	local db = dbenv:connect(file)
	db:setautocommit(false)
	
	-- disable keyword search by default, enable only if ferret is found
	local keyword_search = params['keyword'] == nil and false or params['keyword']
	--@keyword_search &= @@have_ferret
	
	local reasoning = params['reasoning'] or false
	local subprops = reasoning	and {}
	
	local obj =  oo.rawnew(self, {
		class = 'RDFLite',
		reads = true,
		writes = true,
		db = db,
		keyword_search = keyword_search,
		reasoning = reasoning,
		subprops = subprops
	})	
	--[[
	if keyword_search?
		# we initialise the ferret index, either as a file or in memory
		infos = Ferret::Index::FieldInfos.new

		# we setup the fields not to store object's contents
		infos.add_field(:subject, :store => :yes, :index => :no, :term_vector => :no)
		infos.add_field(:object, :store => :no) #, :index => :omit_norms)

		@ferret = if params[:location]
								Ferret::I.new(:path => params[:location] + '.ferret', :field_infos => infos)
							else
								Ferret::I.new(:field_infos => infos)
							end
	end
	]]--
	
	-- turn off filesystem synchronisation for speed
	-- db.synchronous = 'off'

	-- create triples table. ignores duplicated triples
	db:execute('create table if not exists triple(s,p,o,c, unique(s,p,o,c) on conflict ignore)')
	db:commit()

	obj:create_indices(params)
	--@db
	return obj
end

-- returns the number of triples in the datastore (incl. possible duplicates)
function RDFLite:size()
	local cur = self.db:execute('select count(*) from triple')
	local result = tonumber(cur:fetch())
	cur:close()
	return result
end

-- returns all triples in the datastore
function RDFLite:dump()
	local row = {}
	local result = {}
	local cur = self.db:execute('select s,p,o,c from triple')
	while cur:fetch(row, 'a') do
		row.s = row.s or ''
		row.p = row.p or ''
		row.o = row.o or ''		
		row.c = row.c or ''
		table.insert(result, row.s..' '..row.p..' '..row.o..' '..row.c)
	end
	cur:close()
	return result
end

-- deletes all triples from datastore
function RDFLite:clear()
	self.db:execute('delete from triple')
end

-- close adapter and remove it from the ConnectionPool
function RDFLite:close()
	ConnectionPool.remove_data_source(self)
	self.db:close()
end

-- deletes triple(s,p,o,c) from datastore
-- symbol parameters match anything: delete(:s,:p,:o) will delete all triples
-- you can specify a context to limit deletion to that context: 
-- delete(:s,:p,:o, 'http://context') will delete all triples with that context
function RDFLite:delete(s, p, o, c)
	-- convert non-nil input to internal format
	local quad = table.map ( {s,p,o,c}, function(i,r) return r and self:internalise(r) end )

	-- construct where clause for deletion (for all non-nil input)
	local where_clauses = {}
	local conditions = {}
	table.foreach ( quad , function (i, r)
		if r then
			table.insert ( conditions , r )
			table.insert ( where_clauses, SPOC[i].." = %s" )
		end
	end)
	
	-- construct delete string
	local ds = 'delete from triple'
	if not table.empty ( where_clauses ) then
		ds = ds.." where "..table.concat ( where_clauses, ' and ' )
	end

	local pds = prepare(ds, unpack(conditions))
	
	-- execute delete string with possible deletion conditions (for each 
	-- non-empty where clause)
	-- $activerdflog.debug("deleting #{[s,p,o,c].join(' ')}")
	self.db:execute(pds)

	-- delete literal from ferret index
	--@ferret.search_each("subject:\"#{s}\", object:\"#{o}\"") do |idx, score|
	--	@ferret.delete(idx)
	--end if keyword_search?

	return self.db
end

-- adds triple(s,p,o) to datastore
-- s,p must be resources, o can be primitive data or resource
function RDFLite:add(s,p,o,c)
	-- check illegal input
	if not s['uri'] then
		error("adding non-resource "..s.." while adding ("..s..","..p..","..o..","..c..")")
	end
	if not p['uri'] then
		error("adding non-resource "..p.." while adding ("..s..","..p..","..o..","..c..")")
	end

	local triple = table.map ( {s, p, o}, function(i,r) return self:serialise(r) end )
	self:add_ntriples( table.concat ( triple, ' ') .. " .\n", self:serialise(c) )

	-- get internal representation (array)
	--quad = [s,p,o,c].collect {|r| internalise(r) }

	-- insert the triple into the datastore
	--@db.execute('insert into triple values (?,?,?,?)', *quad)

	-- if keyword-search available, insert the object into keyword search
	--@ferret << {:subject => s, :object => o} if keyword_search?
end

-- flushes openstanding changes to underlying sqlite3
function  RDFLite:flush()
	-- since we always write changes into sqlite3 immediately, we don't do 
	-- anything here
	return true
end

-- loads triples from file in ntriples format
function RDFLite:load(location)	
	local context
	if URI:new(location)._host then
		context = location
	else
		context = self:internalise(RDFS.Resource("file:"..location))
	end

 --[[case MIME::Types.of(location)
 when MIME::Types['application/rdf+xml']
	# check if rapper available
	begin 
	  # can only parse rdf/xml with redland
	  # die otherwise
	  require 'rdf/redland'
	  model = Redland::Model.new
	  Redland::Parser.new.parse_into_model(model, location)
	  add_ntriples(model.to_string('ntriples'), location)
	rescue LoadError
	  raise ActiveRdfError, "cannot parse remote rdf/xml file without Redland: please install Redland (librdf.org) and its Ruby bindings"
	end
 else]]--
	local file, err = io.open (location , 'r')	
	if file then
		local data = file:read('*a')		
		file:close()		
		return self:add_ntriples(data, context)
	else
		error(err)
	end	
 --end
end

-- adds ntriples from given context into datastore
function RDFLite:add_ntriples(ntriples, context)
	-- add each triple to db	
	local insert
	local subject, predicate, object
	local s, p, o
	local ntriples = NTriplesParser.parse(ntriples)
	
	table.foreachi(ntriples, function(i,v)
		s, p, o = v[1], v[2], v[3]		
		-- convert triples into internal db format		
		subject, predicate, object = unpack(table.map({s,p,o}, function(i,r) return self:internalise(r) end))
		
		-- insert triple into database
		insert = prepare('insert into triple values (%s,%s,%s,%s);', subject, predicate, object, context)		
		self.db:execute(insert)		
		-- if keyword-search available, insert the object into keyword search
		-- @ferret << {:subject => subject, :object => object} if keyword_search?
	end)

	self.db:commit()

	return self.db
end

-- executes ActiveRDF query on datastore
function RDFLite:query(query)
	
	-- construct query clauses
	local sql, conditions = self:translate(query)
		
	-- executing query, passing all where-clause values as parameters (so that 
	-- sqlite will encode quotes correctly)	
	local row = {}
	local results = {}	
	local cur, err = self.db:execute(prepare(sql, unpack(conditions)))	
	
	if cur then
		while cur:fetch(row) do			
			table.insert(results, table.dup(row))			
		end
	else
		error(err)
	end
	
	-- if ASK query, we check whether we received a positive result count
	if query._ask then
		return {{tonumber(results[1][1]) > 0}}
	elseif query._count then		
		return {{tonumber(results[1][1])}}
	else
		-- otherwise we convert results to ActiveRDF nodes and return them		
		return self:wrap(query, results)
	end
end

-- translates ActiveRDF query into internal sqlite query string
function RDFLite:translate(query)
	local where, conditions = self:construct_where(query)
	local sql = self:construct_select(query) .. self:construct_join(query) .. where .. self:construct_sort(query) .. self:construct_limit(query) 
	return sql, conditions 
end

-- private
-- construct select clause
function RDFLite:construct_select(query)
	-- ASK queries counts the results, and return true if results > 0
	if query._ask then
		return "select count(*)"
	end

	-- add select terms for each selectclause in the query
	-- the term names depend on the join conditions, e.g. t0.s or t1.p
	local select = table.map ( query.select_clauses, function (i,term)				
		return self:variable_name(query, term)
	end)	
	
	-- add possible distinct and count functions to select clause
	local select_clause = ''	
	if query._distinct then
		select_clause = select_clause .. 'distinct '
	end
	select_clause = select_clause .. table.concat(select, ', ')
	if query._count then
		select_clause = "count("..select_clause..")"
	end
	return "select " .. select_clause
end

-- construct (optional) limit and offset clauses
function RDFLite:construct_limit(query)
	local clause = ""

	-- if no limit given, use limit -1 (no limit)
	local limit = query.limits == nil and -1 or query.limits

	-- if no offset given, use offset 0
	local offset = query.offsets == nil and 0 or query.offsets

	clause = clause .. " limit "..limit.." offset "..offset
	return clause
end

-- sort query results on variable clause (optionally)
function RDFLite:construct_sort(query)
	local sort
	if not table.empty(query.sort_clauses) then
		sort = table.map(query.sort_clauses, function(i,term) return self:variable_name(query, term) end)
		return " order by ("..table.concat(sort,',')..")"
	elseif not table.empty(query.reverse_sort_clauses) then
		sort = table.map(query.reverse_sort_clauses, function (i,term) return  self:variable_name(query, term) end)
		return " order by ("..table.concat(sort',')..") DESC"
	else
		return ""
	end
end

-- construct join clause
-- TODO: joins don't work this way, they have to be linear (in one direction 
-- only, and we should only alias tables we didnt alias yet)
-- we should only look for one join clause in each where-clause: when we find 
-- one, we skip the rest of the variables in this clause.
function RDFLite:construct_join(query)
	
	local join_stmt = ''	
	-- no join necessary if only one where clause given
	if table.getn(query.where_clauses) == 1 then
		return ' from triple as t0 '
	end
	
	local where_clauses = ObjectManager.flatten(query.where_clauses)
	local considering = table.select ( table.uniq ( where_clauses ), function(i,w) if type(w) == 'string' then return string.find(w, '^?') end end)
	
	-- constructing hash with indices for all terms
	-- e.g. {?s => [1,3,5], ?p => [2], ... }
	local term_occurrences = {}
	table.foreach( where_clauses, function(index, term)
		term_occurrences[term] = term_occurrences[term] or {}
		local ary = term_occurrences[term]
		table.insert( ary , index )
	end)
	
	local aliases = {}
	local index, term = next(where_clauses)
	while(term) do
	repeat
		-- if the term has been joined with his buddy already, we can skip it		
		if not table.include ( considering, term ) then
			index, term = next ( where_clauses, index )
			break
		end

		-- we find all (other) occurrences of this term
		local indices = term_occurrences[term]

		-- if the term doesnt have a join-buddy, we can skip it
		if table.getn( indices ) == 1 then
			index, term = next ( where_clauses, index )
			break
		end
		
		-- construct t0,t1,... as aliases for term
		-- and construct join condition, e.g. t0.s		
		local termalias = "t"..alias_number(index + 1)
		local termjoin = termalias.."."..SPOC[ spoc_index(index)  ]
	
		local join 
	
		if string.find( join_stmt, termalias ) then
			join = ""
		else
			join = "triple as "..termalias
		end
		
		local ind, i = next ( indices )
		while( i ) do
		repeat			
			-- skip the current term itself
			if i == index then
				ind, i  = next (indices, ind)
				break
			end
			
			-- construct t0,t1, etc. as aliases for buddy,
			-- and construct join condition, e.g. t0.s = t1.p			
			local buddyalias = "t" .. alias_number( i + 1 )						
			local buddyjoin = buddyalias.."."..SPOC[ spoc_index(index) ]			
			-- TODO: fix reuse of same table names as aliases, e.g.
			-- "from triple as t1 join triple as t2 on ... join t1 on ..."
			-- is not allowed as such by sqlite
			-- but on the other hand, restating the aliases gives ambiguity:
			-- "from triple as t1 join triple as t2 on ... join triple as t1 ..."
			-- is ambiguous
			
			if string.find ( join_stmt, buddyalias ) then
				join = join .. " and "..termjoin.." = "..buddyjoin
			else
				join = join .. " join triple as "..buddyalias.." on "..termjoin.." = "..buddyjoin
			end
			ind, i = next( indices, ind )
		break
		until true			
		end
		
		join_stmt = join_stmt .. join
		
		-- remove term from 'todo' list of still-considered terms		
		considering[term] = nil
		index, term = next ( where_clauses, index )
	break
	until true
	end
	
	if join_stmt == '' then
		return " from triple as t0 "
	else
		return " from "..join_stmt.." "
	end
end

	-- construct where clause
function RDFLite:construct_where(query)	
	table.foreach(query.where_clauses, function(i,w) 
		w[1] = w[1] or 'nil'
		w[2] = w[2] or 'nil'
		w[3] = w[3] or 'nil'
		w[4] = w[4] or 'nil'
	end)
	
	-- collecting where clauses, these will be added to the sql string later
	local where = {}
	local conditions
	
	-- collecting all the right-hand sides of where clauses (e.g. where name = 
	-- 'abc'), to add to query string later using ?-notation, because then 
	-- sqlite will automatically encode quoted literals correctly
	local right_hand_sides = {}	
	-- convert each where clause to SQL:
	-- add where clause for each subclause, except if it's a variable		
	table.foreach ( query.where_clauses, function ( level, clause )		
		-- raise ActiveRdfError, "where clause #{clause} is not a triple" unless clause.is_a?(Array)
		if not type(clause) == 'table' then
			error ( "where clause "..clause.." is not a triple" )
		end
		table.foreach ( clause, function ( i, subclause )			
			-- dont add where clause for variables			
			if not ( string.find( tostring(subclause), '^?') or subclause == nil or subclause == 'nil') then				
				conditions = self:compute_where_condition( i, subclause, query.reasoning and self.reasoning )
				if table.getn(conditions) == 1 then
					table.insert ( where , "t"..( level - 1 ).."."..SPOC[i].." = %s" )
					table.insert ( right_hand_sides , conditions[1] )
				else
					conditions = table.map ( conditions, function (i,c) return "'"..c.."'" end )
					table.insert ( where , "t"..( level - 1 ).."."..SPOC[i].." in ("..table.concat( conditions, ',')..")" )
				end
			end
		end)
	end)

	-- if keyword clause given, convert it using keyword index
	if query.keyword and keyword_search then
		local subjects = {}
		local select_subject = table.uniq ( table.map ( query.keywords,  function ( key, subj ) return subj end ) )
		-- raise ActiveRdfError, "cannot do keyword search over multiple subjects" if select_subject.size > 1
		if table.getn ( select_subject ) > 1 then
			error ( "cannot do keyword search over multiple subjects" )
		end
		
		local keywords = table.map ( query.keywords, function ( key, subj ) return key end )
		
		--@ferret.search_each("object:#{keywords}") do |idx,score|
		--	subjects << @ferret[idx][:subject]
		--end
		
		if query._distinct then
			table.uniq(subjects)
		end
		--where << "#{variable_name(query,select_subject.first)} in (#{subjects.collect {'?'}.join(',')})"
		where = where .. self:variable_name(query,select_subject[1]).." in ("..table.concat(table.map(subjects, function(i) return '%s' end), ',')..")"
		right_hand_sides = table.add(right_hand_sides, subjects)
	end

	if table.empty ( where ) then
		return '', {}		
	else
		return "where " .. table.concat ( where, ' and '), right_hand_sides
	end
end

function RDFLite:compute_where_condition(index, subclause, reasoning)
	local conditions = { subclause }

	-- expand conditions with rdfs rules if reasoning enabled
	if reasoning then
		if index == 1 then		
			-- no rule for subjects
		elseif index == 2 then
			-- expand properties to include all subproperties
			if subclause['uri'] then			
				conditions = self:subproperties(subclause)
			end			
		elseif index == 3 then
			-- no rule for objects
		elseif index == 4 then
			-- no rule for contexts
		end
	end

	-- convert conditions into internal format
	return table.map ( conditions, function ( i, c )
										local uri
										if type ( c['uri'] ) == 'function' then
											uri = "<"..c:uri()..">"
										elseif c['uri'] then
											uri = "<"..c.uri..">"
										else
											uri = tostring(c)
										end																			
										return uri 
								   end)
end

function RDFLite:subproperties(self, resource)
	-- compute and store subproperties of this resource 
	-- or use earlier computed value if available
	if not self.subprops[resource] then
		local subproperty = Namespace.lookup( 'rdfs', 'subPropertyOf' )
		local children_query = Query():distinct('?sub'):where('?sub', subproperty, resource)
		children_query.reasoning = false
		local children = children_query:execute()

		if table.empty ( children ) then
			self.subprops[resource] = { resource }
		else
			self.subprops[resource] = { resource , table.flatten ( table.map ( children, function (i,c) return self:subproperties(c) end ) ) }
		end
	end
	return self.subprops[resource]
end

-- returns sql variable name for a queryterm
function RDFLite:variable_name(query,term)
	
	-- look up the first occurence of this term in the where clauses, and compute 
	-- the level and s/p/o position of it
	local index = table.index ( ObjectManager.flatten ( query.where_clauses ), term )
	
	if index == nil then
		-- term does not appear in where clause
		-- but maybe it appears in a keyword clause
			
		-- index would not be nil if we had:
		-- select(:o).where(knud, knows, :o).where(:o, :keyword, 'eyal')
		--
		-- the only possibility that index is nil is if we have:
		-- select(:o).where(:o, :keyword, :eyal) (selecting subject)
		-- or if we use a select clause that does not appear in any where clause

		-- so we check if we find the term in the keyword clauses, otherwise we throw 
		-- an error		
		if table.include ( table.keys ( query.keywords ) , term ) then			
			return "t0.s"
		else
			error ( "unbound variable :" .. tostring(term) .. " in select of " .. query:to_sp() )
		end
	end	
	local termtable = "t"..alias_number(index)	
	local termspo = SPOC[ spoc_index(index) ]	
	return termtable.."."..termspo
end

-- wrap resources into ActiveRDF resources, literals into Strings
function RDFLite:wrap(query, results)
	return table.map ( results, function ( i, row )
		return table.map ( row, function ( j, result ) return self:parse(result) end )
	end)
end

function RDFLite:parse(result)
	local capture1 = Literal:match(result)
	local capture2 = Resource:match(result)
	
	if capture1 then
		-- replace special characters to allow string interpolation for e.g. 'test\nbreak'
		return capture1
	elseif capture2 then
		return RDFS.Resource( capture2 )
	else
		-- when we do a count(*) query we get a number, not a resource/literal
		return result
	end
end

function RDFLite:create_indices(params)
	local sidx = params['sidx'] or false
	local pidx = params['pidx'] or false
	local oidx = params['oidx'] or false
	local spidx = params['spidx'] or true
	local soidx = params['soidx'] or false
	local poidx = params['poidx'] or true
	local opidx = params['opidx'] or false

	-- creating lookup indices	
	if sidx then self.db:execute('create index if not exists sidx on triple(s)') end
	if pidx then self.db:execute('create index if not exists pidx on triple(p)') end
	if oidx then self.db:execute('create index if not exists oidx on triple(o)') end
	if spidx then self.db:execute('create index if not exists spidx on triple(s,p)') end
	if soidx then self.db:execute('create index if not exists soidx on triple(s,o)') end
	if poidx then self.db:execute('create index if not exists poidx on triple(p,o)') end
	if opidx then self.db:execute('create index if not exists opidx on triple(o,p)') end
	self.db:commit()
end

-- transform triple into internal format <uri> and "literal"
function RDFLite:internalise(r)
	if type(r) == 'table' and r['uri'] then
		return "<"..r.uri..">"
	elseif type(r) == 'string' and string.find(r, '^?') then
		return nil
	else
		return '"'..tostring(r)..'"'
	end
end

-- transform resource/literal into ntriples format
function RDFLite:serialise(r)
	if oo.instanceof ( r, RDFS.Resource ) then
		return "<"..r.uri..">"
	else
		return '"'..tostring(r)..'"'
	end
end