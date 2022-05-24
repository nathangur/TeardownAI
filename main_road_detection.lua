--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function init()
		
	points = {} -- point information
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
	]]
	
	indexList = {} -- index in points
	--[[
		[x] : table[float]
			[z] : float
				[stage] : int
	]]
	
	process = {
		points = {},
		edgesDone = false,
		batchSize = 500,
		batchSizeEdges = 1000,
		i = 0
	} -- pos to process
	--[[
		.i : int
		.points : table[float]
			[i]
				.x : float
				.z : float
	]]
	
	status = 1
	
	step = 1 -- default 1, max 4
	radiusSize = step / 2
	maxDeltaPerMeter = 0.75
	
	maxStage = 5
	
	rg = {
		i = 1, -- region growing stuff
		NO_COLOR = -1,
		toCompute = {},
		colorCount = 0,
		done = false,
		batchSize = 500,
		lastBlank = 1,
		colorMapping = {
			region = {},
			color = {},
			size = {}
		},
		status = 1,
		processRegion = {}
	}
	
	world = {}
	world.aa, world.bb = GetBodyBounds(GetWorldBody())
	world.aa = floorVec(world.aa)
	world.bb = floorVec(world.bb)
	
	
	addPointToProcess(world.aa, world.bb)
	
end


function tick(dt)
	--processDebugCross()
	--pointsDebugCross()
	if status > 3 then
		edgesDebugLine(true, 150)
	end
	
	clearConsole()
	DebugPrint("Status: " .. status .. "." .. rg.status)
	if status == 2 then
		processEdges(process.batchSizeEdges)
		DebugPrint(process.i .. " / " .. #points)
	elseif status == 1 then
		processPoint(process.batchSize)
		DebugPrint(process.i .. " / " .. #process.points)
	elseif status == 3 then
		if rg.status == 1 then
			DebugPrint(rg.i .. " / " .. #points)
		elseif rg.status == 2 then
			DebugPrint(rg.i .. " / " .. #points)
		end
		regionGrowing(rg.batchSize)
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

function addPointToProcess(infParam, supParam, s)
	local inf = deepcopy(infParam)
	inf[2] = 0
	local sup = deepcopy(supParam)
	sup[2] = 0
	
	s = s or step
	
	local cursor = {}
	cursor.x = inf[1]
	cursor.z = inf[3]
	
	while cursor.x < sup[1] do
		while cursor.z < sup[3] do
			processInsert(cursor)
			cursor.z = cursor.z + s
		end
		cursor.x = cursor.x + s
		cursor.z = inf[3]
	end
end

function processInsert(v)
	v = deepcopy(v)
	process.points[#process.points + 1] = {}
	process.points[#process.points].x = v.x
	process.points[#process.points].z = v.z
end

function processDebugCross()
	for i=1, #process.points do
		local r = 1
		local g = 0
		if i > process.i then
			r = 0
			g = 1
		end
		DebugCross(Vec(process.points[i].x, 0 , process.points[i].z), r, g, 0, 1)
	end
end

function pointsDebugCross()
	for i=1, #points do
		DebugCross(points[i].pos, 0, 0, 1, 1)
	end
end

function edgesDebugLine(notDebugLine, threshold)
	threshold = threshold or 0
	edgeCount = 0
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
							DebugPrint(regionIndex)
							DebugPrint(rg.colorMapping.size[regionIndex])
							if rg.colorMapping.size[regionIndex] > threshold then
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

function processPoint(batchSize, s)
	batchSize = batchSize or 1
	s = s or step
	for i=1, batchSize do
		local index = i + process.i
		if index > #process.points then
			process.points = {}
			process.i = 0
			process.edgesDone = false
			status = 2
			break
		end
		local addIndex = nil
		if indexList[process.points[index].x] ~= nil then
			addIndex = indexList[process.points[index].x][process.points[index].z]
			-- useful to refresh the list, but not working yet
		end
		if addIndex == nil then
			addIndex = #points + 1
			--DebugPrint(addIndex)
			if indexList[deepcopy(process.points[index].x)] == nil then
				--indexList[deepcopy(process.points[index].x)] = {}
			end
			--indexList[deepcopy(process.points[index].x)][deepcopy(process.points[index].z)] = addIndex
		end
		
		local hit = true
		local hitPos = nil
		local shapeHit = nil
		local toIgnore = {}
		local stage = 1
		local offset = 0
		local bonusOffset = 1.0
		local dist = nil
		
		while hit and stage <= maxStage do
			hit, hitPos, shapeHit, dist = downRaycast(Vec(process.points[index].x, world.bb[2] - offset, process.points[index].z), world.bb[2] - world.aa[2] - offset, false, false, s / 2, toIgnore)
			if hit then
				points[addIndex] = {}
				points[addIndex].pos = hitPos
				points[addIndex].height = hitPos[2]
				points[addIndex].rgDone = false
				points[addIndex].rgIndex = -1
				points[addIndex].color = rg.NO_COLOR
				points[addIndex].neighbors = addNeighbors(hitPos, s)
				
				if indexList[hitPos[1]] == nil then
					indexList[hitPos[1]] = {}
				end
				if indexList[hitPos[1]][hitPos[3]] == nil then
					indexList[hitPos[1]][hitPos[3]] = {}
				end
				indexList[hitPos[1]][hitPos[3]][stage] = addIndex
				
				stage = stage + 1
				toIgnore[#toIgnore + 1] = shapeHit
				
				--local allShapes = QueryAabbShapes(world.aa, world.bb)
				
				local minb = Vec(process.points[index].x - s / 2, world.aa[2], process.points[index].z - s / 2)
				local maxb = Vec(process.points[index].x + s / 2, world.bb[2] - offset, process.points[index].z + s / 2)
				local allShapes = QueryAabbShapes(minb, maxb)
				for i=1, #allShapes do
					if IsShapeTouching(shapeHit, allShapes[i]) then
						toIgnore[#toIgnore + 1] = allShapes[i]
					end
				end
				
				
				offset = offset + dist + bonusOffset
				addIndex = addIndex + 1
			end
		end
	end
	process.i = process.i + batchSize
end

function addNeighbors(origin, s, diag)
	diag = diag or false
	s = s or step
	local flat = deepcopy(origin)
	flat[2] = 0
	
	local n = {}
	
	local offsets = {}
	offsets[#offsets + 1] = Vec(-s, 0, 0)
	offsets[#offsets + 1] = Vec(s, 0, 0)
	offsets[#offsets + 1] = Vec(0, 0, -s)
	offsets[#offsets + 1] = Vec(0, 0, s)
	if diag then
		offsets[#offsets + 1] = Vec(-s, 0, -s)
		offsets[#offsets + 1] = Vec(s, 0, -s)
		offsets[#offsets + 1] = Vec(-s, 0, s)
		offsets[#offsets + 1] = Vec(s, 0, s)
	end
	
	for i=1, #offsets do
		for j=1, maxStage do
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

function processEdges(batchSize, s)
	batchSize = batchSize or 1
	s = s or step
	for i=1, batchSize do
		local index = i + process.i
		if index > #points then
			process.edgesDone = true
			status = 3
			rg.i = 1
			rg.toCompute = {}
			rg.colorCount = 0
			rg.lastBlank = 1
			rg.done = false
			rg.status = 1
			process.i = 0
			--DebugPrint("Edges Done")
			break
		end
		
		local neighbors = {}
		--DebugPrint("vvv")
		--DebugPrint(points[i].pos[1] .. " " .. points[i].pos[3])
		for j=1, #points[index].neighbors do
			--DebugPrint(points[i].neighbors[j].x .. " " .. points[i].neighbors[j].z)
			--if points[i].neighbors[j].x > points[i].pos[1] or points[i].neighbors[j].z > points[i].pos[3] then
				neighbors[#neighbors + 1] = points[index].neighbors[j]
			--end
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
			
			if npointIndex == nil then
				points[index].neighbors[j].edge = false
				--DebugPrint("nil")
				--points[npointIndex].neighbors[j].edge = false
			elseif math.abs(npoint.height - points[index].height) / s > maxDeltaPerMeter then
				--DebugPrint("delta")
				points[index].neighbors[j].edge = false
			elseif abRaycast(points[index].pos, npoint.pos, false, 0) then
				points[index].neighbors[j].edge = false
				--DebugPrint("raycast")
			end
			if points[index].neighbors[j].edge then
				newNeighbors[#newNeighbors + 1] = points[index].neighbors[j]
			end
		end
		points[index].neighbors = deepcopy(newNeighbors)
	end
	process.i = process.i + batchSize
end

function regionGrowing(batchSize)
	threshold = threshold or 0 -- stricly >
	batchSize = batchSize or 1
	
	for i=1, batchSize do
		--local index = i + rg.i
		if rg.done then
			status = 4
			rg.toCompute = {}
			break
		end
		--DebugPrint(rg.status)
		if rg.status == 1 then -- assign colors
			local pointIndex = getNextGreyIndex()
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
							convertColor(points[index].color, points[rg.i].color)
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
				local exist = false
				--[[for k=1, #rg.colorMapping.region do
					if points[j].color == rg.colorMapping.region[k] then
						exist = true
						break
					end
				end]]
				exist = (existRegion[points[j].color] ~= nil)
				
				if not exist then
					existRegion[points[j].color] = true
					rg.colorMapping.region[#rg.colorMapping.region + 1] = points[j].color
					points[j].regionIndex = #rg.colorMapping.region
					regionSize[points[j].color] = 1
					regionIndex[points[j].color] = points[j].regionIndex
					rg.colorMapping.size[points[j].regionIndex] = 1
					rg.colorMapping.color[#rg.colorMapping.color + 1] = Vec(rand(100) / 100, rand(100) / 100, rand(100) / 100)
				else
					--[[local index = nil
					for k=1, #rg.colorMapping.region do
						if rg.colorMapping.region[k] == points[j].color then
							index = k
							points[j].regionIndex = k
							break
						end
					end
					rg.colorMapping.size[index] = rg.colorMapping.size[index] + 1]]
					points[j].regionIndex = regionIndex[points[j].color]
					rg.colorMapping.size[points[j].regionIndex] = rg.colorMapping.size[points[j].regionIndex] + 1
					regionSize[points[j].color] = regionSize[points[j].color] + 1
				end
			end
			--DebugPrint("Regions: " .. #rg.colorMapping.region)
			--DebugWatch("Regions:", #rg.colorMapping.region)
			--for j=1, #rg.colorMapping.region do
				--DebugPrint("R" .. rg.colorMapping.region[j] .. " = " .. rg.colorMapping.size[j])
				--DebugWatch("R" .. rg.colorMapping.region[j], rg.colorMapping.size[j])
			--end
			rg.status = 4
			rg.done = true
			break
		end
	end
end

function getNextGreyIndex()
	rg.i = rg.i + 1
	return rg.toCompute[rg.i - 1]
end

function convertColorOld(oldColor, newColor)
	for i=1, #points do
		if points[i].color == oldColor then
			points[i].color = newColor
		end
	end
end

function convertColor(oldColor, newColor)
	for i=1, #rg.processRegion[oldColor] do
		points[rg.processRegion[oldColor][i]].color = newColor
		rg.processRegion[newColor][#rg.processRegion[newColor] + 1] = rg.processRegion[oldColor][i]
	end
	rg.processRegion[oldColor] = {}
end




















































