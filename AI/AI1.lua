--create ai traffic in Teardown using Teardown's API: https://teardowngame.com/modding/api.html and using the open files.

function init()
	vehicle = FindVehicle("aicar", true)
	node = FindLocations("node", true)

	vehicleTransform = GetVehicleTransform(vehicle)
	nodeTransform = GetLocationTransform(node)

end

function update(dt)
	if vehicle ~= nil then
		-- DebugPrint("Vehicle found")
		DebugPrint("Vehicle Position: " .. vehicleTransform[1] .. " " .. vehicleTransform[2] .. " " .. vehicleTransform[3])
		DebugPrint("Node Position: " .. nodeTransform[1] .. " " .. nodeTransform[2] .. " " .. nodeTransform[3])
		-- DebugPrint("Distance: " .. VecDistance(vehicleTransform,nodeTransform))
		if VecDistance(vehicleTransform,nodeTransform) < 2 then
			DebugPrint("Node reached")
		end
	end
end

function tick()

end

--create an algorithm to create a path for the ai traffic to follow from one nodeTransform to the next.

function Pathing()
	
end