-- Simple implementation of a single-layer neural network

local nn = {}

function init()
  -- Initialize the neural network
  nn:init(3, 6, 3) -- 3 inputs (speed, distance to goal, and current steering), 6 hidden neurons, 3 outputs (steering, throttle, and handbrake)

  originalTransform = GetVehicleTransform(vehicle)
  vehicle = FindVehicle('aicar', true)  
  loc = FindLocation('node1', true)
  goal_pos = GetLocationTransform(loc).pos

end

-- ADAM optimizer parameters
local adam_m = {} 
local adam_v = {}
local beta1 = 0.9
local beta2 = 0.999
local epsilon = 0.00001

-- Parameters that you can adjust based on your specific requirements
local TARGET_SPEED = 20  
local MAX_DISTANCE = 500  
local MAX_STEERING = 1
local MAX_BRAKE = 1
-- Initialize network
function nn:init(input_size, hidden_size, output_size)

  -- Hidden layer weights and biases
  self.hidden_weights = {}
  self.hidden_biases = {}
  for i=1,hidden_size do
    self.hidden_weights[i] = {}
    self.hidden_biases[i] = math.random() * 0.1 - 0.05
    
    for j=1,input_size do
      self.hidden_weights[i][j] = math.random() * 0.1 - 0.05  
    end
  end

  -- Output layer weights and biases
  self.output_weights = {}
  self.output_biases = {}
  for i=1,output_size do
    self.output_weights[i] = {}
    self.output_biases[i] = math.random() * 0.1 - 0.05

    for j=1,hidden_size do
      self.output_weights[i][j] = math.random() * 0.1 - 0.05
    end
  end
end

-- Sigmoid function
local function sigmoid(x)
    return 1 / (1 + math.exp(-x)) 
end

-- Squared error loss function
local function loss(pred, actual)
    local sum = 0
    for i=1,#pred do
      local diff = pred[i] - actual[i]
      sum = sum + diff*diff 
    end
    return sum
end

-- Calculate gradients w.r.t weights using backward pass
local function get_gradients(inputs, hiddens, outputs, targets)

    -- Output layer gradients
    local out_grads = {}
    for i=1,#outputs do
        local diff = outputs[i] - targets[i] 
        out_grads[i] = diff * outputs[i] * (1 - outputs[i]) 
    end

    -- Hidden layer gradients
    local hid_grads = {}
    for i=1,#hiddens do
        local sum = 0
        for j=1,#out_grads do
            sum = sum + out_grads[j] * nn.output_weights[j][i] 
        end
        hid_grads[i] = sum * hiddens[i] * (1 - hiddens[i]) 
    end

    return out_grads, hid_grads
end

-- Forward pass
function nn:forward(inputs)

    local hiddens = {}

    -- Hidden layer forward pass
    for i=1,#self.hidden_weights do
      local sum = self.hidden_biases[i]
      for j=1,#inputs do -- ensure we don't exceed the size of inputs
          DebugWatch('inputs[j] ',inputs[j])
          DebugWatch('self.hidden_weights[i][j] ', self.hidden_weights[i][j])
          DebugWatch('i ',i)
          DebugWatch('j ',j)
          sum = sum + inputs[j] * self.hidden_weights[i][j]
      end
      hiddens[i] = sigmoid(sum)
    end
    -- Output layer forward pass
    local outputs = {}
    for i=1,#self.output_weights do
        local sum = self.output_biases[i]
        for j=1,#hiddens do
            sum = sum + hiddens[j] * self.output_weights[i][j] 
        end
        outputs[i] = sigmoid(sum)
    end  
  
    return hiddens, outputs
end

-- Update weights using gradients and a learning rate
local lr = 0.1

function nn:update_weights(out_grads, hid_grads, hiddens, inputs)

  -- Update output weights
  for i=1,#out_grads do
    for j=1,#self.output_weights[1] do
        if self.output_weights[i][j] ~= nil then
            self.output_weights[i][j] = self.output_weights[i][j] - lr * out_grads[i] * hiddens[j]  
        end
    end
    -- Update output bias
    self.output_biases[i] = self.output_biases[i] - lr * out_grads[i]
  end

  -- Update hidden weights
  for i=1,#hid_grads do
    for j=1,#inputs do
        self.hidden_weights[i][j] = self.hidden_weights[i][j] - lr * hid_grads[i] * inputs[j]
    end
    -- Update hidden bias
    self.hidden_biases[i] = self.hidden_biases[i] - lr * hid_grads[i]
  end
end

-- Training function
function nn:train(inputs, targets)

    local hiddens, outputs = self:forward(inputs)

    local out_grads, hid_grads = get_gradients(inputs, hiddens, outputs, targets)

    self:update_weights(out_grads, hid_grads, hiddens, inputs)

    return outputs, targets 
end

-- Normalize data
local function normalize(value, max)
    return value / max
end

-- Generate training data
local function get_training_data(vehicle, goal_pos)
  local body = GetVehicleBody(vehicle)
  local vehicle_transform = GetVehicleTransform(vehicle)
  local distance = VecLength(VecSub(goal_pos, vehicle_transform.pos))
  
  -- Normalize inputs
  local speed_vector = GetBodyVelocity(body)
  local speed_magnitude = VecLength(speed_vector)
  local speed = normalize(speed_magnitude, TARGET_SPEED)
  local dist = normalize(distance, MAX_DISTANCE)

  -- Targets 
  local targets = {TARGET_SPEED, 0, 0} -- Added a third target for handbrake
  
  return {speed, dist}, targets
end

local ui = {}

ui.trainingInfo = {
  iteration = 0,
  loss = 0
}

ui.vehicleInfo = {
  speed = 0,
  steering = 0,
  throttle = 0,
  handbrake = false      
}

function ui.updateTrainingInfo(iteration, loss)
  ui.trainingInfo.iteration = iteration
  ui.trainingInfo.loss = loss
end

function ui.updateVehicleInfo(speed, steering, throttle, handbrake)
  ui.vehicleInfo.speed = speed  
  ui.vehicleInfo.steering = steering
  ui.vehicleInfo.throttle = throttle
  ui.vehicleInfo.handbrake = handbrake
end

-- Improved network visualization

local nodeSpacing = 2
local nodeRadius = 20

-- Store current UI cursor position
local uiCursorX = 0
local uiCursorY = 0

-- Start a new shape at cursor position 
function UiMoveTo(x, y)
  uiCursorX = x
  uiCursorY = y
end

-- Add line from cursor pos to (x, y) and update cursor
function UiLineTo(x, y)
  DrawLine(Vec(uiCursorX, uiCursorY, 0), Vec(x, y, 0))
  uiCursorX = x
  uiCursorY = y  
end

-- Close path back to original cursor position
function UiClosePath()
  UiLineTo(uiCursorX, uiCursorY) 
end


function UiCircle(radius, value, thickness)
  UiFont("MOD/lucon.ttf", 16)  
  local numSegments = 20
  
  local a = 0
  local step = (math.pi * 2) / numSegments

  UiTranslate(0, radius) -- Start at top
  
  for i=1,numSegments do
    local x = math.cos(a) * radius
    local y = math.sin(a) * radius
    if i == 1 then
      UiMoveTo(x, y) 
    else
      UiLineTo(x, y)
    end
    a = a + step
  end
  
  UiClosePath()

  UiAlign("center middle")
  UiText(value)
end

-- Visualize network 
function ui.drawNetwork(inputs, hiddens, outputs)

  local nodeSpacing = 6

  UiPush()
    UiFont("MOD/lucon.ttf", 16)  
    UiTranslate(0, 30) -- Extra spacing

    -- Inputs
    local inputSize = #inputs
    UiText("Inputs:", true)
    
    UiTranslate(0, nodeSpacing) -- Reset transform
    
    for i=1,inputSize do
      local value = inputs[i]
      UiTranslate(i * nodeSpacing, 0)
      UiCircle(nodeRadius, value, 10)
      UiText(value, true)
    end

    -- Hidden
    UiTranslate(0, nodeSpacing)
    
    local hiddenSize = #hiddens
    UiText("Hidden:", true)

    UiTranslate(0, nodeSpacing) -- Reset transform

    for i=1,hiddenSize do
      local value = hiddens[i]
      UiTranslate(i * nodeSpacing, 0)     
      UiCircle(nodeRadius, value, 10)
      UiText(value, true)
    end

    -- Output
    UiTranslate(0, nodeSpacing)
    UiText("Outputs:", true)

    UiTranslate(0, nodeSpacing) -- Reset transform

    local outputSize = #outputs
    for i=1,outputSize do
      local value = outputs[i]
      UiTranslate(i * nodeSpacing, 0)
      UiCircle(nodeRadius, value, 10)
      UiText(value, true)
    end

  UiPop()

end

function ui.draw()

  UiPush()

    -- Move UI to top right
    UiTranslate(UiWidth() - 300, 20) 

    -- Draw training info
    UiFont("MOD/lucon.ttf", 16)  
    UiText("Training iteration: " .. ui.trainingInfo.iteration)
    UiTranslate(0, 20) 
    UiText("Loss: " .. tostring(ui.trainingInfo.loss))

    -- Draw vehicle info
    UiTranslate(0, 40)
    UiText("Speed: " .. ui.vehicleInfo.speed)
    UiTranslate(0, 20)
    UiText("Steering: " .. ui.vehicleInfo.steering)
    UiTranslate(0, 20)  
    UiText("Throttle: " .. ui.vehicleInfo.throttle)
    UiTranslate(0, 20)
    UiText("Handbrake: " .. tostring(ui.vehicleInfo.handbrake))

  ui.drawNetwork(ui.inputs, ui.hiddens, ui.outputs)

  UiPop()

end

-- Fix turning left issue  
local function clamp(value, min, max)
  return math.min(math.max(value, min), max)  
end

local function processSteering(steering)
  steering = clamp(steering, -1, 1) 
  return steering
end

-- Reset vehicle if it goes off the map
function reset_vehicle_if_off_map(vehicle, originalTransform)
  local killbox = FindTrigger("killbox")
  if not IsVehicleInTrigger(killbox, vehicle) then
    -- Reset vehicle and network
    local body = GetVehicleBody(vehicle)  
    SetBodyTransform(body, originalTransform)
    -- Store the new original transform of the vehicle
    originalTransform = GetVehicleTransform(vehicle)
    -- Reset network weights
    nn:init(3, 6, 3) 
  end
end

-- Update vehicle control
function control_vehicle(vehicle, goal_pos, originalTransform)
  -- Get inputs and predict outputs
  local inputs, targets = get_training_data(vehicle, goal_pos)
  local hiddens, outputs = nn:forward(inputs)
  
  ui.inputs = inputs 
  ui.hiddens = hiddens
  ui.outputs = outputs

  -- Get steering and throttle
  local steering = processSteering(outputs[1])
  local throttle = outputs[2]

  -- Reset vehicle if it goes off the map
  --reset_vehicle_if_off_map(vehicle, originalTransform)

  -- Update UI
  local speed = VecLength(GetBodyVelocity(GetVehicleBody(vehicle)))
  ui.updateVehicleInfo(speed, steering, throttle, false)

  -- Control vehicle
  DriveVehicle(vehicle, steering, throttle) 
end

function draw(dt)



    -- Draw UI
    ui.draw()

end

-- Main script loop
function tick(dt)

  -- Generate training data
  local inputs, targets = get_training_data(vehicle, goal_pos)
            
  -- Train network
  ui.trainingInfo.loss = nn:train(inputs, targets)
  ui.updateTrainingInfo(ui.trainingInfo.iteration + 1, ui.trainingInfo.loss)
              
  -- Control vehicle
  control_vehicle(vehicle, goal_pos, originalTransform)
end