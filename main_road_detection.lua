--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function init()
	
	mappingList = {}
	maxMappingCount = 1
	
	--md.points -- point information
	--[[
		[i]
			.pos : Vec -- position
			.height : float -- same as pos[2]
			.rgDone : bool
			.regionIndex : int
			.color : int -- used for region growing
			.neighbors : table[int] -- all neighborers points
				[j]
					.x : float
					.z : float
					.stage : int
					.edge : bool
			.pf : table -- pathfinder stuff for a point
				.color : int -- 0: waiting, 1: in queue, 2: done
				.previous : int -- index of the previous point in the path
				.dist : table -- squared distance...
					.a : float -- ...from the starting point
					.b : float -- ...from the target point
		.pf : table -- pathfinder stuff for all the points
				.queue : table -- the queue of grey (color 1) points
				.a : Vec() -- starting point
				.b : Vec() -- target point
				.batchSize : int
				.path : table : Vec() -- the list of points to travel to
				.current : int -- index of the node currently computed
				.first : first pass of the pathfinder
	]]
	
	-- md.indexList -- index in points
	--[[
		[x] : table[float]
			[z] : float
				[stage] : int
	]]
	
	--[[
		.i : int
		.points : table[float]
			[i]
				.x : float
				.z : float
	]]
	
	displayRegions = false
	abort = false
	
	world = {}
	world.aa, world.bb = GetBodyBounds(GetWorldBody())
	world.aa = floorVec(world.aa)
	world.bb = floorVec(world.bb)
	
end


function tick(dt)

	if InputPressed('shift') then
		displayRegions = not displayRegions
	end
	
	if InputPressed('x') then
		abort = true
	else
		abort = false
	end
	
	if InputPressed('c') then
		if #mappingList < maxMappingCount then
			mappingList[#mappingList + 1] = makeMappingData(world.aa, world.bb)
		end
	end
	
	for i=1, #mappingList do
		mapping(dt, mappingList[i])
		DebugWatch("Path", getPathState(mappingList[i]))
		if abort then
			abortPath(mappingList[i])
		end
		if #mappingList[i].pf.path > 0 then -- display path
			displayPath(mappingList[i])
		end
		if displayRegions then -- display regions
			edgesDebugLine(true, mappingList[i])
		end
		if mappingList[i].verbose.progression then -- display progression
			printProgressionMapping(mappingList[i])
		end
		if mappingList[i].verbose.timer then -- display timer
			updateTimer(mappingList[i], dt)
			debugWatchTable(mappingList[i].timer)
		end
end
end


function update(dt)
	
end


function draw(dt)

end

---------------------------------

function clearConsole()
	for i=1, 25 do
		DebugPrint("")
	end
end

function rand(minv, maxv)
	minv = minv or nil
	maxv = maxv or nil
	if minv == nil then
		return math.random()
	end
	if maxv == nil then
		return math.random(minv)
	end
	return math.random(minv, maxv)
end

--Helper to return a random number in range mi to ma
function randFloat(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

--Return a random vector of desired length
function randVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function floorVec(v)
	return Vec(math.floor(v[1]), math.floor(v[2]), math.floor(v[3]))
end

function round(value, dec)
	local d = dec or 0
	local mult = math.pow(10, d)
	return math.floor(value * mult) / mult
end

function roundVec(vec, dec)
	local d = dec or 0
	for i=1, #vec do
		vec[i] = round(vec[i])
	end
	return vec
end

function exportToRegistry()
	--TODO
end

function importFromRegistry()
	--TODO
end

function debugWatchTable(t)
	for k, v in pairs(t) do
		if type(v) ~= "boolean" then
			DebugWatch(k, string.format("%.1f", v))
		end
	end
end

---------------------------------

function downRaycast(origin, maxDist, ignoreVehicles, ignoreWater, radius, toIgnore)
	
	ignoreWater = ignoreWater or false
	maxDist = maxDist or (wbb[2] - waa[2])
	radius = radius or 0
	
	local dir = Vec(0, -1, 0)
	local hitPos = nil
	
	for i=1, #toIgnore do
		QueryRejectShape(toIgnore[i])
	end
	
	local hit, dist, normal, shape = QueryRaycast(origin, dir, maxDist, radius, false)
	if hit then
		hitPos = deepcopy(origin)
		hitPos[2] = hitPos[2] - dist
		if IsPointInWater(hitPos) and not ignoreWater then
			hit = false
		end
	end
	
	return hit, deepcopy(hitPos), shape, dist
end

function abRaycast(a, b, ignoreVehicles, radius)
	ignoreVehicles = ignoreVehicles or false
	radius = radius or 0
	
	local diff = VecSub(b, a)
	local dir = VecNormalize(diff)
	
	local hit, dist, normal, shape = QueryRaycast(a, dir, VecLength(diff), radius, false)
	
	return hit
end

function addPointToProcess(md)
	local inf = deepcopy(md.bounds.aa)
	inf[2] = 0
	local sup = deepcopy(md.bounds.bb)
	sup[2] = 0
	
	local cursor = {
		x = inf[1],
		z = inf[3]
	}
	
	while cursor.x < sup[1] do
		while cursor.z < sup[3] do
			processInsert(md, cursor)
			cursor.z = cursor.z + md.step
		end
		cursor.x = cursor.x + md.step
		cursor.z = inf[3]
	end
end

function processInsert(md, v)
	local process = md.process
	v = deepcopy(v)
	process.points[#process.points + 1] = {}
	process.points[#process.points].x = v.x
	process.points[#process.points].z = v.z
end

function pathfinderDebugCross(md)
	
	local points = md.points

	for i=1, #points do
		if points[i].pf.color > 0 then
		local r = 0
		local g = 1
		local b = 0
		if points[i].pf.color == 1 then
			r = 1
			g = 0
		end
		DebugCross(points[i].pos, r, g, b, 1)
		end
	end
end

function processDebugCross(md)
	for i=1, #md.process.points do
		local r = 1
		local g = 0
		if i > md.process.i then
			r = 0
			g = 1
		end
		DebugCross(Vec(md.process.points[i].x, 0 , md.process.points[i].z), r, g, 0, 1)
	end
end

function pointsDebugCross(md)

	local points = md.points

	for i=1, #points do
		DebugCross(points[i].pos, 0, 0, 1, 1)
	end
end

function makeMappingData(minBound, maxBound)
	local md = {
		points = {},
		pf = {
			batchSize = 1000,
			queue = {},
			path = {},
			first = true,
			current = nil,
			a = nil,
			b = nil,
			dijkstra = false,
			status = "idle"
		},
		indexList = {},
		process = {
			points = {},
			i = 0,
			batchSizeRaycast = 200,
			batchSizeEdges = 400,
			edgesDone = false
		},
		bounds = {
			aa = floorVec(deepcopy(minBound)),
			bb = floorVec(deepcopy(maxBound))
		},
		step = 1.0, -- default = 1.0, min = 0.1, max = 4.0
		radius = 0,
		i = 0,
		status = 0,
		maxStage = 10,
		connex8 = false,
		threshold = 0,
		maxDeltaPerMeter = 1.1,
		rg = {  -- region growing
			NO_COLOR = -1,
			toCompute = {},
			colorCount = 0,
			done = false,
			batchSize = 2500,
			lastBlank = 1,
			colorMapping = {
				region = {},
				color = {},
				size = {}
			},
			status = 1,
			processRegion = {},
			i = 0
		},
		timer = { -- timer
			raycast = 0,
			edges = 0,
			regionMapping = 0,
			regionMerging = 0,
			regionColoring = 0,
			pathfinder = 0,
			total = 0
		},
		verbose = {
			progression = true,
			timer = true
		}
	}
	
	md.radius = md.step / 2
	
	return deepcopy(md)
end

function mapping(dt, md)

	local status = md.status
	local rg  = md.rg
	local pf = md.pf
	local process = md.process

	if md.status == 0 then -- adding point position to compute vertically
		addPointToProcess(md)
		md.status = 1

	elseif md.status == 1 then
		processPoint(md)
			
	elseif md.status == 2 then
		processEdges(md)
		
	elseif md.status == 3 then
		regionGrowing(md)
		
	elseif md.status == 4 then
		if VecLength(pf.a) > 0 and VecLength(pf.b) > 0 then
			md.status = 5
			resetPathfinder(md)
		elseif InputPressed("grab") then
			pf.b = GetPlayerTransform().pos
		elseif InputPressed("usetool") then
			pf.a = GetPlayerTransform().pos
		end
		
	elseif md.status == 5 then
		computePath(md)
		
	elseif md.status == 6 then
		pf.a = Vec(0, 0, 0)
		pf.b = Vec(0, 0, 0)
		md.status = 4
	end
end

function updateTimer(md, dt)
	local rg = md.rg
	local timer = md.timer
	if md.status > 0 and md.status < 4 then
		timer.total = timer.total + dt
	end
	if md.status == 0 then -- adding point position to compute vertically
	elseif md.status == 1 then
		timer.raycast = timer.raycast + dt
	elseif md.status == 2 then
		timer.edges = timer.edges + dt
	elseif md.status == 3 then
		if rg.status == 1 then
			timer.regionMapping = timer.regionMapping + dt
		elseif rg.status == 2 then
			timer.regionMerging = timer.regionMerging + dt
		elseif rg.status == 3 then
			timer.regionColoring = timer.regionColoring + dt
		end
	elseif md.status == 4 then
	elseif md.status == 5 then
		if md.pf.first then	
			timer.pathfinder = dt
		else
			timer.pathfinder = timer.pathfinder + dt
		end
	elseif md.status == 6 then
	end
end

function getPathState(md)
	return md.pf.status
end

function abortPath(md)
	md.pf.a = Vec(0, 0, 0)
	md.pf.b = Vec(0, 0, 0)
	md.status = 4
	md.pf.status = "idle"
end

function printProgressionMapping(md)
	local process = md.process
	local rg = md.rg
	if md.status == 0 then -- adding point position to compute vertically
		DebugWatch("Progression", "Ready to compute.")	
	elseif md.status == 1 then
		DebugWatch("Progression", md.process.i .. " / " .. #md.process.points)	
	elseif md.status == 2 then
		DebugWatch("Progression", process.i .. " / " .. #md.points)
	elseif md.status == 3 then
		if rg.status == 1 then
			DebugWatch("Progression", rg.i .. " / " .. #md.points)
		elseif rg.status == 2 then
			DebugWatch("Progression", rg.i .. " / " .. #md.points)
		elseif rg.status == 3 then
		end
	elseif md.status == 4 then
			DebugWatch("Progression", "Computation done, pathfinder ready.")
	elseif md.status == 5 then
			DebugWatch("Progression", "Computing path...")
	elseif md.status == 6 then
	end
end

function edgesDebugLine(notDebugLine, md)
	edgeCount = 0
	local points = md.points
	local indexList = md.indexList
	local rg = md.rg
	
	for i=1, #points do
		for j=1, #points[i].neighbors do
			if points[i].neighbors[j].x > points[i].pos[1] or points[i].neighbors[j].z > points[i].pos[3] then
				if points[i].neighbors[j].edge then
					--edgeCount = edgeCount + 1
					local npointIndex = nil
					if indexList[points[i].neighbors[j].x] ~= nil then
						if indexList[points[i].neighbors[j].x][points[i].neighbors[j].z] ~= nil then
							npointIndex = indexList[points[i].neighbors[j].x][points[i].neighbors[j].z][points[i].neighbors[j].stage]
						end
					end
					--DebugPrint(npointIndex)
					local npoint = points[npointIndex]
					if npoint ~= nil then
						local r = 0
						local g = 1
						local b = 0
						local alpha = 1
						local valid = true
						if #rg.colorMapping.region > 0 then
							local regionIndex = npoint.regionIndex
							r = rg.colorMapping.color[regionIndex][1]
							g = rg.colorMapping.color[regionIndex][2]
							b = rg.colorMapping.color[regionIndex][3]
							
							valid = false
							if rg.colorMapping.size[regionIndex] > md.threshold then
								valid = true
							end
						end
						
						if valid then
							if notDebugLine then
								DrawLine(points[i].pos, npoint.pos, r, g, b, alpha)
							else
								DebugLine(points[i].pos, npoint.pos, r, g, b, alpha)
							end
						end
					end
				end
			end
		end
	end
end

function processPoint(md)
	local points = md.points
	local batchSize = md.process.batchSizeRaycast
	local process = md.process
	local indexList = md.indexList
	
	for i=1, batchSize do
		local index = i + process.i
		if index > #process.points then
			process.points = {}
			process.i = 0
			process.edgesDone = false
			md.status = 2
			break
		end
		local addIndex = nil
		if indexList[process.points[index].x] ~= nil then
			addIndex = indexList[process.points[index].x][process.points[index].z]
			-- useful to refresh the list, but not working yet
		end
		if addIndex == nil then
			addIndex = #points + 1
		end
		
		local hit = true
		local hitPos = nil
		local shapeHit = nil
		local toIgnore = {}
		local stage = 1
		local offset = 0
		local bonusOffset = md.step
		local dist = nil
		
		while hit and stage <= md.maxStage do
			hit, hitPos, shapeHit, dist = downRaycast(Vec(process.points[index].x, world.bb[2] - offset, process.points[index].z), world.bb[2] - world.aa[2] - offset, false, false, md.radius, toIgnore)
			if hit then
				points[addIndex] = {}
				points[addIndex].pos = hitPos
				points[addIndex].height = hitPos[2]
				points[addIndex].rgDone = false
				points[addIndex].rgIndex = -1
				points[addIndex].color = md.rg.NO_COLOR
				points[addIndex].neighbors = addNeighbors(hitPos, md)
				points[addIndex].pf = {
					color = 0,
					dist = {}
				}
				
				if indexList[hitPos[1]] == nil then
					indexList[hitPos[1]] = {}
				end
				if indexList[hitPos[1]][hitPos[3]] == nil then
					indexList[hitPos[1]][hitPos[3]] = {}
				end
				indexList[hitPos[1]][hitPos[3]][stage] = addIndex
				
				stage = stage + 1
				
				toIgnore[#toIgnore + 1] = shapeHit
				
				local minb = Vec(process.points[index].x - md.radius, world.bb[2] - offset - md.step, process.points[index].z - md.radius)
				local maxb = Vec(process.points[index].x + md.radius, world.bb[2] - offset, process.points[index].z + md.radius)
				local allShapes = QueryAabbShapes(minb, maxb)
				for i=1, #allShapes do
					toIgnore[#toIgnore + 1] = allShapes[i]
				end
				
				offset = offset + dist + bonusOffset
				addIndex = addIndex + 1
			end
		end
	end
	process.i = process.i + batchSize
end

function addNeighbors(origin, md)
	local flat = deepcopy(origin)
	flat[2] = 0
	
	local n = {}
	
	local offsets = {}
	offsets[#offsets + 1] = Vec(-md.step, 0, 0)
	offsets[#offsets + 1] = Vec(md.step, 0, 0)
	offsets[#offsets + 1] = Vec(0, 0, -md.step)
	offsets[#offsets + 1] = Vec(0, 0, md.step)
	if md.connex8 then
		offsets[#offsets + 1] = Vec(-md.step, 0, -md.step)
		offsets[#offsets + 1] = Vec(md.step, 0, -md.step)
		offsets[#offsets + 1] = Vec(-md.step, 0, md.step)
		offsets[#offsets + 1] = Vec(md.step, 0, md.step)
	end
	
	for i=1, #offsets do
		for j=1, md.maxStage do
			local pos = VecAdd(flat, offsets[i])
			n[#n + 1] = {}
			n[#n].x = pos[1]
			n[#n].z = pos[3]
			n[#n].stage = j
			n[#n].edge = false
		end
	end
	
	return deepcopy(n)
end

function processEdges(md)

	local points = md.points
	local batchSize = md.process.batchSizeEdges
	local process = md.process
	local indexList = md.indexList
	
	for i=1, batchSize do
		local index = i + process.i
		if index > #points then
			process.edgesDone = true
			md.status = 3
			md.rg.i = 1
			md.rg.toCompute = {}
			md.rg.colorCount = 0
			md.rg.lastBlank = 1
			md.rg.done = false
			md.rg.status = 1
			process.i = 0
			break
		end
		
		local neighbors = {}
		
		for j=1, #points[index].neighbors do
			neighbors[#neighbors + 1] = points[index].neighbors[j]
		end
		
		local newNeighbors = {}
		
		for j=1, #neighbors do
			points[index].neighbors[j].edge = true
			local npointIndex = nil
			if indexList[points[index].neighbors[j].x] ~= nil then
				if indexList[points[index].neighbors[j].x][points[index].neighbors[j].z] ~= nil then
					npointIndex = indexList[points[index].neighbors[j].x][points[index].neighbors[j].z][points[index].neighbors[j].stage]
				end
			end
			local npoint = points[npointIndex]
			
			if npointIndex == nil then -- nil failure
				points[index].neighbors[j].edge = false
				
			elseif math.abs(npoint.height - points[index].height) / md.step > md.maxDeltaPerMeter then -- delta failure
				points[index].neighbors[j].edge = false
				
			elseif abRaycast(points[index].pos, npoint.pos, false, md.radius - 0.2) then -- raycast failure
				points[index].neighbors[j].edge = false
				
			end
			if points[index].neighbors[j].edge then
				newNeighbors[#newNeighbors + 1] = points[index].neighbors[j]
			end
		end
		points[index].neighbors = deepcopy(newNeighbors)
	end
	process.i = process.i + batchSize
end

function regionGrowing(md)

	local batchSize = md.rg.batchSize
	local points = md.points
	local rg = md.rg
	local indexList = md.indexList
	
	for i=1, batchSize do
		if rg.done then
			md.status = 4
			rg.status = 1
			rg.toCompute = {}
			break
		end
		
		if rg.status == 1 then -- assign colors
			local pointIndex = getNextGreyIndex(rg)
			local point = points[pointIndex]
			if point == nil then
				for j=rg.lastBlank, #points do
					if points[j].color == rg.NO_COLOR then
						pointIndex = j
						point = points[j]
						rg.colorCount = rg.colorCount + 1
						point.color = rg.colorCount
						rg.processRegion[point.color] = {}
						rg.processRegion[point.color][#rg.processRegion[point.color] + 1] = j
						rg.lastBlank = j
						break
					end
				end
				if point == nil then
					rg.status = 2
					rg.i = 1
					break
				end
			end
			for j=1, #point.neighbors do
				local index = nil
				if indexList[point.neighbors[j].x] ~= nil then
					if indexList[point.neighbors[j].x][point.neighbors[j].z] ~= nil then
						index = indexList[point.neighbors[j].x][point.neighbors[j].z][point.neighbors[j].stage]
					end
				end
				if index ~= nil then
					local color = points[index].color
					if color ~= rg.NO_COLOR then
						point.color = color
						rg.processRegion[point.color][#rg.processRegion[point.color] + 1] = pointIndex
					else
						if not points[index].rgDone then
							points[index].rgDone = true
							rg.toCompute[#rg.toCompute + 1] = index
						end
					end
				end
			end
			
		elseif rg.status == 2 then -- merge regions
			if rg.i > #points then
				rg.status = 3
				break
			end
			for j=1, #points[rg.i].neighbors do
				if points[rg.i].neighbors[j].edge then
					local index = nil
					if indexList[points[rg.i].neighbors[j].x] ~= nil then
						if indexList[points[rg.i].neighbors[j].x][points[rg.i].neighbors[j].z] ~= nil then
							index = indexList[points[rg.i].neighbors[j].x][points[rg.i].neighbors[j].z][points[rg.i].neighbors[j].stage]
						end
					end
					if index ~= nil then
						if points[index].color ~= points[rg.i].color then
							convertColor(points[index].color, points[rg.i].color, md)
						end
					end
				end
			end
			rg.i = rg.i + 1
			
		elseif rg.status == 3 then -- get visual colors
			rg.colorMapping.region = {}
			rg.colorMapping.color = {}
			rg.colorMapping.size = {}
			local existRegion = {}
			local regionSize = {}
			local regionIndex = {}
			for j=1, #points do
				local exist = (existRegion[points[j].color] ~= nil)
				
				if not exist then
					existRegion[points[j].color] = true
					rg.colorMapping.region[#rg.colorMapping.region + 1] = points[j].color
					points[j].regionIndex = #rg.colorMapping.region
					regionSize[points[j].color] = 1
					regionIndex[points[j].color] = points[j].regionIndex
					rg.colorMapping.size[points[j].regionIndex] = 1
					rg.colorMapping.color[#rg.colorMapping.color + 1] = Vec(rand(100) / 100, rand(100) / 100, rand(100) / 100)
					
				else
					points[j].regionIndex = regionIndex[points[j].color]
					rg.colorMapping.size[points[j].regionIndex] = rg.colorMapping.size[points[j].regionIndex] + 1
					regionSize[points[j].color] = regionSize[points[j].color] + 1
				end
			end

			rg.status = 4
			rg.done = true
			initPathFinder(md.pf, false)
			break
		end
	end
end

function getNextGreyIndex(rg)
	rg.i = rg.i + 1
	return rg.toCompute[rg.i - 1]
end

function convertColor(oldColor, newColor, md)
	local rg = md.rg
	local points = md.points
	
	for i=1, #rg.processRegion[oldColor] do
		points[rg.processRegion[oldColor][i]].color = newColor
		rg.processRegion[newColor][#rg.processRegion[newColor] + 1] = rg.processRegion[oldColor][i]
	end
	rg.processRegion[oldColor] = {}
end

function initPathFinder(pf, skipPointReset)
	
	skipPointReset = skipPointReset or false
	if skipPointReset == false then
		pf = {
			a = Vec(0, 0, 0),
			b = Vec(0, 0, 0)
		}
	end
	pf.queue = {}
	pf.path = {}
	pf.batchSize = 150
	pf.current = nil
	pf.first = true
end

function computePath(md)
	
	local points = md.points
	local pf = md.pf
	local batchSize = md.pf.batchSize
	pf.status = "busy"
	if pf.first then
		pf.a = getClosestNodeIndex(pf.a, md)
		pf.b = getClosestNodeIndex(pf.b, md)
		if points[pf.a].color ~= points[pf.b].color then
			md.status = 6
			--DebugWatch("Not the same region!", rand(100))
			pf.status = "fail"
		end
		pf.first = false
		local returnVal = addInQueue(pf.a, nil, md)
		--DebugWatch("first", returnVal)
	end
	
	local complete = false
	for i=1, batchSize do
		pf.current = getNextIndexInQueue(md)
		if pf.current == pf.b or pf.current == nil then
			complete = true
			break
		else
			addNeighboursToQueue(md)
		end
	end
	
	if complete then
		-- build the path table
		local cursor = pf.b
		while cursor ~= nil and cursor ~= pf.a do
			pf.path[#pf.path + 1] = cursor
			cursor = points[cursor].pf.previous
		end
		pf.path[#pf.path + 1] = cursor -- add the pf.a point
		md.status = 6
		pf.status = "done"
	end
end

function addInQueue(pointIndex, previousIndex, md)
	
	local points = md.points
	local pf = md.pf
	
	if points[pointIndex].pf.color == 0 then
		points[pointIndex].pf.color = 1
		points[pointIndex].pf.previous = previousIndex
		if previousIndex ~= nil then
			points[pointIndex].pf.dist.a = points[previousIndex].pf.dist.a + VecLength(VecSub(points[previousIndex].pos, points[pointIndex].pos))
		else
			points[pointIndex].pf.dist.a = 0
		end
		points[pointIndex].pf.dist.b = VecLength(VecSub(points[pointIndex].pos, points[pf.b].pos))
		pf.queue[#pf.queue + 1] = pointIndex
		--DebugWatch("color", points[pointIndex].pf.color)
		return true -- added
	end
	return false -- not added
end

function getClosestNodeIndex(inputVec, md)
	local p = deepcopy(inputVec)
	p[1] = p[1] - (p[1] % md.step) + (world.aa[1] % md.step)
	p[3] = p[3] - (p[3] % md.step) + (world.aa[3] % md.step)
	local indexStageList = md.indexList[p[1]][p[3]]
	local points = md.points
	local bmu = {
		index = nil,
		dist = 0
	}

	for stage=1, #indexStageList do
		if indexStageList[stage] ~= nil then
			local dist = VecLength(VecSub(points[indexStageList[stage]].pos, p))
			if bmu.index == nil or dist < bmu.dist then
				bmu.index = indexStageList[stage]
				bmu.dist = dist
			end
		end
	end
	return bmu.index
end

function getNextIndexInQueue(md)

	local points = md.points
	local pf = md.pf

	local bmu = {
		index = nil,
		dist = 0
	}
	
	local updatedQueue = {}
	
	for i=1, #pf.queue do
		local dist = 0
		if pf.dijkstra then
			dist = points[pf.queue[i]].pf.dist.a
		else
			dist = points[pf.queue[i]].pf.dist.b
		end
		if bmu.index == nil or dist < bmu.dist then
			if bmu.index ~= nil then
				updatedQueue[#updatedQueue + 1] = bmu.index
			end
			bmu.index = pf.queue[i]
			bmu.dist = dist
		else
			updatedQueue[#updatedQueue + 1] = pf.queue[i]
		end
	end
	
	if bmu.index ~= nil then
		points[bmu.index].pf.color = 2
	end
	pf.queue = deepcopy(updatedQueue)
	
	return bmu.index
end

function addNeighboursToQueue(md)

	local points = md.points
	local pf = md.pf
	local indexList = md.indexList

	for i=1, #points[pf.current].neighbors do
		local index = indexList[points[pf.current].neighbors[i].x][points[pf.current].neighbors[i].z][points[pf.current].neighbors[i].stage]
		if points[pf.current].neighbors[i].edge then
			if points[index].pf.color == 0 then
				addInQueue(index, pf.current, md)
			elseif points[index].pf.color == 1 and points[pf.current].pf.dist.a < points[points[index].pf.previous].pf.dist.a then
				points[index].pf.previous = pf.current
			end
		end
	end
end

function displayPath(md)

	local points = md.points
	local pf = md.pf
	
	for i=1, #pf.path - 1 do
		DrawLine(points[pf.path[i]].pos, points[pf.path[i + 1]].pos, 1, 1, 0, 1)
	end
end

function resetPathfinder(md)

	local points = md.points

	for i=1, #points do
		points[i].pf = {
			color = 0,
			dist = {}
		}
	end
	initPathFinder(md.pf, true)
end










































