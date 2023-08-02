vehiclee = FindVehicle('aicar')

function init()
	camera_roof_joint = FindJoint('sdv_camera_roof_joint')
	vehicle_forced_active = false
end
function tick(dt)
	--DebugWatch("vehicle", vehicle)
	DebugWatch("GetVehicleHealth(vehicle)", GetVehicleHealth(vehiclee))
	DebugWatch("vehicle_forced_active", vehicle_forced_active)
	DebugWatch("GetPlayerVehicle()", GetPlayerVehicle())
end
function update(dt)
	if GetVehicleHealth(vehiclee) > 0 and (vehicle_forced_active or (GetPlayerVehicle() ~= 0)) then
		SetJointMotor(camera_roof_joint, 30, 6)
	else
		SetJointMotor(camera_roof_joint, 0, 0)
	end
end
