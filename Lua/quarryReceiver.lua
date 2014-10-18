--Quarry Receiver Version 3.5.4
--Made by Civilwargeeky
--[[
Ideas:

    
]]
--[[
Recent Changes:
  Completely Remade!
]]

local commandHelpParagraph = [[
Stop: Stops the turtle where it is
Return: The turtle will return to its starting point, drop off its load, and stop
Drop: Turtle will immediately go and drop its inventory
Pause: Pauses the turtle
Resume: Resumes paused turtles
Help: This :D
]]


--Config
local doDebug = true --For testing purposes
local ySizes = 3 --There are 3 different Y Screen Sizes right now

--Initializing Program-Wide Variables
local expectedMessage = "Civil's Quarry" --Expected initial message
local expectedFingerprint = "quarry"
local replyMessage = "Turtle Quarry Receiver" --Message to respond to  handshake with
local replyFingerprint = "quarryReceiver"
local stopMessage = "stop"
local expectedFingerprint = "quarry"
local themeFolder = "quarryResources/receiverThemes/"
local modemSide --User can specify a modem side, but it is not necessary
local modem --This will be the table for the modem

--Generic Functions--
local function debug(...)
  if doDebug then return print(...) end
end
local function clearScreen(x,y, periph)
  periph, x, y = periph or term, x or 1, y or 1
  periph.clear()
  periph.setCursorPos(x,y)
end
  
local function swapKeyValue(tab)
  for a,b in pairs(tab) do
    tab[b] = a
  end
  return tab
end
local function copyTable(tab)
  local toRet = {}
  for a,b in pairs(tab) do
    toRet[a] = b
  end
  return toRet
end
local function checkChannel(num)
  num = tonumber(num) 
  if not num then return false end
  if 1 <= num and num <= 65535 then
    return num
  end
  return false
end
local function align(text, xDim)
  text = tostring(text) or ""
  if #text >= xDim then return text end
  for i=1, xDim-#text do
    text = " "..text
  end
  return text
end
local function center(text, xDim)
  xDim = xDim or dim[1] --Temp fix
  local a = (xDim-#text)/2
  for i=1, a do
    text = " "..text.." "
  end
  return text  
end


local function testPeripheral(periph, periphFunc)
  if not periph or type(periph) ~= "table" then return false end
  if periph[periphFunc]() == nil then --Expects string because the function could access nil
    periph.isDisconnected = true --My current solution
    return false
  end
  return true
end

local function initModem() --Sets up modem, returns true if modem exists
  if not testPeripheral(modem, "isWireless") then
    if peripheral.getType(modemSide or "") == "modem" then
      modem = peripheral.wrap(modemSide)
      return true
    end
    modem = peripheral.find("modem")
    return modem and true or false
  end
  return true
end

--COLOR/THEME RELATED
local themes = {} --Loaded themes, gives each one a names
local function newTheme(name)
  local self = {name = name}
  self.addColor = function(self, name, text, back) --Background is optional. Will not change if nil
    self[name] = {text = text, background = back}
    return self --Allows for chaining :)
  end
  themes[name] = self
  return self
end
  
--This is how adding colors will work
screenClass.themeColors=newTheme("default")
  :addColor("title", colors.green, colors.gray)
  :addColor("subtitle", colors.white)
  :addColor("pos", colors.green)
  :addColor("dim", colors.lightBlue)
  :addColor("extra", colors.lightGray)
  :addColor("error", colors.red, colors.white)
  :addColor("info", colors.blue, colors.lightGray)
  :addColor("inverse", colors.yellow, colors.lightGray)
  :addColor("command", colors.lightBlue)
  :addColor("help", colors.red, colors.white)
  :addColor("background", colors.white, colors.black)

  
--==SCREEN CLASS FUNCTIONS==
local screenClass = {} --This is the class for all monitor/screen objects
screenClass.screens = {} --A simply numbered list of screens
screenClass.sides = {} --A mapping of screens by their side attached
screenClass.channels = {} --A mapping of receiving channels that have screens attached. Used for the receiver part
screenClass.sizes = {{7,18,29,39,50}, (5,12,19} , computer = {51, 19}, turtle = {39,13}, pocket = {26,20}}

screenClass.setTextColor = function(self, color) --Accepts raw color
  if color and self.term.isColor() then
    self.textColor = color
    return self.term.setTextColor(color)
  end
end
screenClass.setBackgroundColor = function(self, color) --Accepts raw color
  if color and obj.isColor() then
    currBackgroundColor = color
    return obj.setBackgroundColor(color)
  end
end
screenClass.setColor = function(self, color) --Wrapper, accepts themecolor objects
  return self.setTextColor(color.text) and self.setBackgroundColor(color.background)
end

screenClass.themeFile = "default" --Setting super for fallback
screenClass.theme = themes.default


screenClass.new = function(side, receive, themeFile)
  local self = {}
  setmetatable(obj, {__index = screenClass}) --Establish Hierarchy
  self.side = side
  if side == "computer" then
    self.term = term
  else
    self.term = peripheral.wrap(side)
    if not (self.term and peripheral.getType(side) == "monitor") then --Don't create an object if it doesn't exist
      if doDebug then
        error("No monitor on side "..tostring(side))
      end
      self = nil --Save memory?
      return false
    end
  end
  
  --Channels and ids
  self.receive = receive --Receive Channel
  self.send = nil --Reply Channel, obtained in handshake
  self.id = #screenClass.screens+1
  --Colors
  self.themeName = themeFile
  self.theme = nil --Will be set by setTheme

  self.isColor = self.term.isColor() --Just for convenience
  --Other Screen Properties
  self.dim = {self.term.getSize()} --Raw dimensions
  --Initializations
  self.isDone = false --Flag for when the turtle is done transmitting
  self.size = {} --Screen Size, assigned in setSize
  self.textColor = colors.white --Just placeholders until theme is loaded and run
  self.backColor = colors.black
  self.toPrint = {}
  self.isComputer = false
  self.isTurtle = false
  self.isPocket = false
  self.acceptsInput = false
  self.legacy = false --Whether it expects tables or strings
  self.rec = { --Initial values for all displayed numbers
    label = "Quarry Bot",
    id = 1, 
    percent = 0,
    relxPos = 0,
    zPos = 0,
    layersDone = 0,
    x = 0,
    z = 0,
    layers = 0,
    openSlots = 0,
    mined = 0,
    moved = 0,
    chestFull = false,
    isAtChest = false,
    isGoingToNextLayer = false,
    foundBedrock = false,
    fuel = 0,
    volume = 0,
    distance = 0,
    yPos = 0
    --Maybe add in some things like if going to then add a field
  }
  
  screenClass.screens[self.id] = self
  screenClass.sides[self.side] = self
  if self.receive then
    screenClass.channels[self.receive] = self --If anyone ever asked, you could have multiple screens per channel, but its silly if no one ever needs it
  end
  self:setSize() --Finish Initialization
  self:setTheme()
  return self
end

screenClass.removeEntry = function(tab) --Cleanup function
  if type(id) == "number" then --Expects table, can take id
    tab = screenClass.screens[id]
  end
  if tab == "REMOVED" then return end
  screenClass.screens[tab.id] = "REMOVED" --Not nil because screw up len()
  screenClass.sides[tab.side] = nil
  screenClass.channels[tab.receive] = nil
  if modem and modem.isOpen(tab.receive) then
    modem.close(tab.receive)
  end
end

--Init Functions
screenClass.setSize = function(self) --Sets screen size
  if self.side ~= "computer" and not self.term then self.term = peripheral.wrap(self.side) end
  if not self.term then --If peripheral is having problems/not there. Don't go further than term, otherwise index nil (maybe?)
    self.updateDisplayTable = function() end --Do nothing on screen update, overrides class
  else --This allows for class inheritance
    self.updateDisplayTable = nil --Remove function in case it exists, defaults to super
    self:init() --In case objects have special updateDisplayTable methods
  end
  local tab = screenClass.sizes
  for a=1, 2 do --Want x and y dim
    for b=1, #tab[a] do --Go through all normal sizes, x and y individually
      if tab[a][b] <= self.dim[a] then --This will set size higher until false
        self.size[a] = b
      end
    end
  end
  local function isThing(toCheck, thing) --E.G. isThing(self.dim,"computer")
    return toCheck[1] == tab[thing][1] and toCheck[2] == tab[thing][2]
  end
  self.isComputer = isThing(self.dim, "computer")
  self.isTurtle = isThing(self.dim, "turtle")
  self.isPocket = isThing(self.dim, "pocket")
  self.acceptsInput = self.isComputer or self.isTurtle or self.isPocket
  return self
end

screenClass.setTheme = function(self)
  if not themes[self.themeName] then --If we don't have it already, try to load it
    local fileName = self.themeName
    local newTheme --Init for placement later
    if fs.exists(themeFolder) then fileName = themeFolder..fileName end
    if fs.exists(fileName) then
      local file = fs.open(fileName, "r")
      --Loop through all the lines, adding colors
      file.close()
    else
      --Does not set so falls back to super
      return false
    end
    
   end
end

--Adds text to the screen buffer
screenClass.tryAddRaw = function(self, line, text, color, ...) --This will try to add text if Y dimension is a certain size
  local doAdd = {...} --booleans for small, medium, and large
  text = text or "NIL"
  color = color or {text = colors.white}
  for i=1, ySizes do --As of now there are 3 Y sizes
    if doAdd[i] and screenSize[2] == i then --If should add this text for this screen size and the monitor is this size
      if #text <= self.dim[1] then
        self.toPrint[line] = {text = text, color = color}
        return true
      else
        debug("Tried adding ",text," on line ",#self.toPrint+1," but was too long")
      end
    end
  end
  return false
end
screenClass.tryAdd = function(self, text, color,...) --Just a wrapper
  return self:tryAddRaw(#self.toPrint+1, text, color, ...)
end

screenClass.reset = function(self,color)
  self.setColor(color)
  self.term.clear()
  self.term.setCursorPos(1,1)
end
screenClass.say = function(self, text, color)
  local currColor = self.backgroundColor
  color = color or {}
  self.setColor(color)
  if doDebug and #text > dim[1] then error("Tried printing: '"..text.."', but was too big") end
  for i=1, self.dim[1]-#text do --This is so the whole line's background gets filled.
    text = text.." "
  end
  self.term.write(text)
  local pos = ({obj.getCursorPos()})[2] or setSize() or 1 --If current yPos not found, sets screen size and moves cursor to 1
  self.term.setCursorPos(1, pos+1)
end

screenClass.updateDisplayTable = function(self, isDone)
  local str = tostring
  self.toPrint = {} --Reset table
  local message, theme = self.rec, self.themeColors
  
  if not message.isDone then --Normally
    if self.size[1] == 1 then --Small Width Monitor
      if not self:tryAdd(message.label, theme.title, false, false, true) then --This will be a title, basically
        self:tryAdd("Quarry!", theme.title, false, false, true)
      end
      
      self:tryAdd("-Fuel-", theme.subtitle , false, true, true)
      if not self:tryAdd(str(message.fuel), nil, false, true, true) then --The fuel number may be bigger than the screen
        self:tryAdd("A lot", nil, false, true, true)
      end
      
      self:tryAdd("--%%%--", theme.subtitle, false, true, true)
      self:tryAdd(align(str(message.percent).."%", 7), theme.pos , false, true, true) --This can be an example. Print (receivedMessage).percent in blue on all different screen sizes
      self:tryAdd(center(str(message.percent).."%"), theme.pos, true) --I want it to be centered on 1x1
      
      self:tryAdd("--Pos--", theme.subtitle, false, true, true)
      self:tryAdd("X:"..align(str(message.relxPos), 5), theme.pos, true, true, true)
      self:tryAdd("Z:"..align(str(message.zPos), 5), theme.pos , true, true, true)
      self:tryAdd("Y:"..align(str(message.layersDone), 5), theme.pos , true, true, true)
      
      if not self:tryAdd(str(message.x).."x"..str(message.z).."x"..str(message.layers), theme.dim , true) then --If you can't display the y, then don't
        self:tryAdd(str(message.x).."x"..str(message.z), theme.dim , true)
      end
      self:tryAdd("--Dim--", theme.subtitle, false, true, true)
      self:tryAdd("X:"..align(str(message.x), 5), theme.dim, false, true, true)
      self:tryAdd("Z:"..align(str(message.z), 5), theme.dim, false, true, true)
      self:tryAdd("Y:"..align(str(message.layers), 5), theme.dim, false, true, true)
      
      self:tryAdd("-Extra-", theme.subtitle, false, false, true)
      self:tryAdd(align(textutils.formatTime(os.time()):gsub(" ","").."", 7), theme.extra, false, false, true) --Adds the current time, formatted, without spaces.
      self:tryAdd("Open:"..align(str(message.openSlots),2), theme.extra, false, false, true)
      self:tryAdd("Dug"..align(str(message.mined), 4), theme.extra, false, false, true)
      self:tryAdd("Mvd"..align(str(message.moved), 4), theme.extra, false, false, true)
      if message.chestFull then
        self:tryAdd("ChstFll", theme.error, false, false, true)
      end
      
    end
    if self.size[1] == 2 then --Medium Monitor
      if not self:tryAdd(message.label, theme.title, false, false, true) then --This will be a title, basically
        self:tryAdd("Quarry!", theme.title, false, false, true)
      end
      
      self:tryAdd("-------Fuel-------", theme.subtitle , false, true, true)
      if not self:tryAdd(str(message.fuel), nil, false, true, true) then --The fuel number may be bigger than the screen
        toPrint[#toPrint] = nil
        self:tryAdd("A lot", nil, false, true, true)
      end
      
      self:tryAdd(str(message.percent).."% Complete", theme.pos , true, true, true) --This can be an example. Print (receivedMessage).percent in blue on all different screen sizes
      
      self:tryAdd("-------Pos--------", theme.subtitle, false, true, true)
      self:tryAdd("X Coordinate:"..align(str(message.relxPos), 5), theme.pos, true, true, true)
      self:tryAdd("Z Coordinate:"..align(str(message.zPos), 5), theme.pos , true, true, true)
      self:tryAdd("On Layer:"..align(str(message.layersDone), 9), theme.pos , true, true, true)
      
      if not self:tryAdd("Size: "..str(message.x).."x"..str(message.z).."x"..str(message.layers), theme.dim , true) then --This is already here... I may as well give an alternative for those people with 1000^3quarries
        self:tryAdd(str(message.x).."x"..str(message.z).."x"..str(message.layers), theme.dim , true)
      end
      self:tryAdd("-------Dim--------", theme.subtitle, false, true, true)
      self:tryAdd("Total X:"..align(str(message.x), 10), theme.dim, false, true, true)
      self:tryAdd("Total Z:"..align(str(message.z), 10), theme.dim, false, true, true)
      self:tryAdd("Total Layers:"..align(str(message.layers), 5), theme.dim, false, true, true)
      self:tryAdd("Volume"..align(str(message.volume),12), theme.dim, false, false, true)
      
      self:tryAdd("------Extras------", theme.subtitle, false, false, true)
      self:tryAdd("Time: "..align(textutils.formatTime(os.time()):gsub(" ","").."", 12), theme.extra, false, false, true) --Adds the current time, formatted, without spaces.
      self:tryAdd("Used Slots:"..align(str(16-message.openSlots),7), theme.extra, false, false, true)
      self:tryAdd("Blocks Mined:"..align(str(message.mined), 5), theme.extra, false, false, true)
      self:tryAdd("Spaces Moved:"..align(str(message.moved), 5), theme.extra, false, false, true)
      if message.chestFull then
        self:tryAdd("Chest Full, Fix It", theme.error, false, true, true)
      end
    end
    if self.size[1] >= 3 then --Large or larger screens
      if not self:tryAdd(message.label..align(" Turtle #"..str(message.id),dim[1]-#message.label), theme.title, true, true, true) then
        self:tryAdd("Your turtle's name is long...", theme.title, true, true, true)
      end
      self:tryAdd("Fuel: "..align(str(message.fuel),dim[1]-6), nil, true, true, true)
      
      self:tryAdd("Percentage Done: "..align(str(message.percent).."%",dim[1]-17), theme.pos, true, true, true)
      
      local var1 = math.max(#str(message.x), #str(message.z), #str(message.layers))
      local var2 = (dim[1]-5-var1+3)/3
      self:tryAdd("Pos: "..align(" X:"..align(str(message.relxPos),var1),var2)..align(" Z:"..align(str(message.zPos),var1),var2)..align(" Y:"..align(str(message.layersDone),var1),var2), theme.pos, true, true, true)
      self:tryAdd("Size:"..align(" X:"..align(str(message.x),var1),var2)..align(" Z:"..align(str(message.z),var1),var2)..align(" Y:"..align(str(message.layers),var1),var2), theme.dim, true, true, true)
      self:tryAdd("Volume: "..str(message.volume), theme.dim, false, true, true)
      self:tryAdd("",nil, false, false, true)
      self:tryAdd(center("____---- EXTRAS ----____"), theme.subtitle, false, false, true)
      self:tryAdd(center("Time:"..align(textutils.formatTime(os.time()),8)), theme.extra, false, true, true)
      self:tryAdd(center("Current Day: "..str(os.day())), theme.extra, false, false, true)
      self:tryAdd("Used Inventory Slots: "..align(str(16-message.openSlots),dim[1]-22), theme.extra, false, true, true)
      self:tryAdd("Blocks Mined: "..align(str(message.mined),dim[1]-14), theme.extra, false, true, true)
      self:tryAdd("Blocks Moved: "..align(str(message.moved),dim[1]-14), theme.extra, false, true, true)
      self:tryAdd("Distance to Turtle: "..align(str(message.distance), dim[1]-20), theme.extra, false, false, true)
      self:tryAdd("Actual Y Pos (Not Layer): "..align(str(message.yPos), dim[1]-26), theme.extra, false, false, true)
      
      if message.chestFull then
        self:tryAdd("Dropoff is Full, Please Fix", theme.error, false, true, true)
      end
      if message.foundBedrock then
        self:tryAdd("Found Bedrock! Please Check!!", theme.error, false, true, true)
      end
      if message.isAtChest then
        self:tryAdd("Turtle is at home chest", theme.info, false, true, true)
      end
      if message.isGoingToNextLayer then
        self:tryAdd("Turtle is going to next layer", theme.info, false, true, true)
      end
    end
  else --If is done
    if screenSize[1] == sizesEnum.small then --Special case for small monitors
      self:tryAdd("Done", theme.title, true, true, true)
      self:tryAdd("Dug"..align(str(message.mined),4), theme.pos, true, true, true)
      self:tryAdd("Fuel"..align(str(message.fuel),3), theme.pos, true, true, true)
      self:tryAdd("-------", theme.subtitle, false,true,true)
      self:tryAdd("Turtle", theme.subtitle, false, true, true)
      self:tryAdd(center("is"), theme.subtitle, false, true, true)
      self:tryAdd(center("Done!"), theme.subtitle, false, true, true)
    else
      self:tryAdd("Done!", theme.title, true, true, true)
      self:tryAdd("Blocks Dug: "..str(message.mined), theme.inverse, true, true, true)
      self:tryAdd("Cobble Dug: "..str(message.cobble), theme.pos, false, true, true)
      self:tryAdd("Fuel Dug: "..str(message.fuelblocks), theme.pos, false, true, true)
      self:tryAdd("Others Dug: "..str(message.other), theme.pos, false, true, true)
      self:tryAdd("Curr Fuel: "..str(message.fuel), theme.inverse, true, true, true)
    end
  end
end
self.handshakeDisplay = function(self)
  self.toPrint = {}
  local half = math.floor(self.dim[2]/2)
  if self.size[1] == 1 then
    self:tryAddRaw("Waiting", half-2, self.theme.error, true, true, true)
    self:tryAdd("For Msg", half-1, self.theme.error, true, true, true)
    self:tryAdd("On Chnl", half, self.theme.error, true, true, true)
    self:tryAdd(tostring(self.receive), half+1, self.theme.error, true, true, true)
  elseif self.size[2] == 2 then
    
  else --Big size screen
  end
end


--Misc
screenClass.init = function() return true end --Currently used by computer screen to replace its original method
screenClass.setHandshakeDisplay = function(self)
  self.handshakeDisplay = nil --So it will default to screenClass
end

--==ARGUMENTS==

--[[
Parameters:
  -help/-?/help/?
  -receiveChannel [channel] --For only the main screen
  -theme --Sets a default theme
  -screen [side] [channel] [theme]
  -station
  -auto --Prompts for all sides, or you can supply a list of receive channels for random assignment!
]]

--tArgs and peripheral list init
local tArgs = {...}
local parameters = {} --Each command is stored with arguments
local parameterIndex = 0 --So we can add new commands to the right table
for a,b in ipairs(tArgs) do
  val = b:lower()
  if val == "help" or val == "-help" or val == "?" or val == "-?" then
    displayHelp() --To make
    error("The End of Help",0)
  end
  if val:match("^%-") then
    parameterIndex = parameterIndex + 1
    parameters[parameterIndex] = {param = val:sub(2)} --Starts a chain with the command. Can be unpacked later
    parameters[val:sub(2)] = {} --Needed for force/before/after parameters
  elseif parameterIndex ~= 0 then
    table.insert(parameters[parameterIndex], b) --b because arguments should be case sensitive for filenames
    table.insert(parameters[parameters[parameterIndex][1]], b) --Needed for force/after parameters
  end
end

--Options before screen loads
if parameters.theme then
  screenClass:setTheme(parameters.theme[1] or "")
end

--Init Computer Screen Object
local computer = screenClass.new("computer", parameters.receivechannel and parameters.receivechannel[1])--This sets channel, checking if parameter exists

--Technically, you could have any screen be the station, but oh well.
if parameters.station then --This will set the screen update to display stats on all other monitors. For now it does little
  screenClass.receiveChannels[computer.receive] = nil --Because it doesn't have a channel
  computer.receive = -1 --So it doesn't receive messages
  computer.init = function(comp) --This gets by setSize
    computer.updateDisplayTable = function(self)
      for a, b in pairs(screenClass.sides) do
        tryAdd("Side: ", a," ",b.id," ",b.receive, theme.pos, false, true, true) --Prints info about all screens
      end
    end
  end
end


for i=1, #parameters do --Do actions for parameters that can be used multiple times
  local command, args = parameters[i].param, parameters[i] --For ease
  
  if command == "screen" then
    screenClass.new(args[1], args[2], args[3])
  end
  
end

if parameters.auto then
  local tab = peripheral.getNames()
  for i=1, #tab do
    if peripheral.getType(tab[i]) == "modem" then
      screenClass.new(tab[i], parameters.auto[i]) --You can specify a list of channels in "auto" parameter
    end
  end
end


--==SET UP==
clearScreen()
print("Welcome to Quarry Receiver!")
sleep(2)

while not initModem() do
  clearScreen()
  print("No modem is connected, please attach one")
  os.pullEvent("peripheral")
end
debug("Modem successfully connected!")

--Making sure all screens have a channel
for a, b in pairs(screenClass.sides) do
  while not b.receive do
    clearScreen()
    print("Screen ",a," has no channel")
    print("Enter the channel from the turtle!")
    local input = tonumber(read())
    if checkChannel(input) then
      if not screenClass.channels[input] then
        b.receive = input
        screenClass.channels[input] = b
      else
        print("That channel has already been taken")
      end
    else
      print("That is not a valid number")
    end
    sleep(1)
  end
end

for a, b in pairs(screenClass.channels) do --Open up all the channels
  if not modem.isOpen(a) then
    modem.open(a)
  end
end
--Handshake will be handled in main loop


--[[Workflow
  Wait for events
  modem_message
    if valid channel and valid message, update appropriate screen
  char
    if any letter, add to command string if room.
    if enter key
      if valid self command, execute command. Commands:
        command [side] [command] --If only one screen, then don't need channel. Send a command to a turtle
        screen [side] [channel] [theme] --Links a new screen to use.
        remove [side] --Removes a screen
  peripheral_detach
    check what was lost, if modem, set to nil. If screen side, do screen:setSize()
  peripheral
    check if need modem, then set modem
    prompt link screen?
  monitor_resize
    resize proper screen

]]
local messageToSend --This will be a command string sent to turtle
local queuedMessage --If a command needs to be sent, this gets set
while true do
  local event, par1, par2, par3, par4, par5 = os.pullEvent()
    if event == "modem_message" and screenClass.channels[par2] then --If we got a message for a screen that exists
      local screen = screenClass.channels[par2] --For convenience
      if not screen.send then --This is the handshake
        debug("Checking handshake. Received: ",par4)
        local flag = false
        if par4 == expectedMessage then
          screen.legacy = true --Accepts serialized tables
          flag = true
        elseif type(par4) == "table" and par4.message == expectedMessage and par4.fingerprint == expectedFingerprint then
          screen.legacy = false
          flag = true
        end
        
        if flag then 
          debug("Screen ",screen.side," received a handshake")
          screen.send = par3
          screen:setSize() --Resets update method to proper since channel is set
          debug("Sending back on ",screen.send)
          modem.transmit(screen.send,screen.receive, replyMessage)
        end
      
      else --Everything else is for regular messages
      
        local rec
        if screen.legacy then --We expect strings here
          if type(par4) == "string" then
            rec = textutils.unserialize(par4)
            rec.distance = par5
          end
        elseif type(par4) == "table" and par4.fingerprint == expectedFingerprint then --Otherwise, we check if it is valid message
          rec = par4.message
          if not par4.distance then --This is cool because it can add distances from the repeaters
            rec.distance = par5
          else
            rec.distance = par4.distance + par5
          end
       end
       
       if rec then
        rec.distance = math.floor(rec.distance)
        rec.label = rec.label or "Quarry!"
        screen.rec = rec --Set the table
        screen:updateDisplayTable() --isDone is queried inside this
        screen:reset(screen.theme.background)
        for i=1, screen.dim[2] do
          local tab = screen.toPrint[i]
          if tab then
            screen:say(tab.text, tab.color)
          else
            screen:say("",screen.color.background) --Advance lines and all that
          end
        end
        local toSend
        if queuedMessage then
          toSend = queuedMessage
          queuedMessage = nil
        else
          toSend = replyMessage
        end
        if screen.legacy then
          modem.transmit(screen.send,screen.receive, toSend) --For older versions of minecraft
        else
          modem.transmit(screen.send,screen.receive, {fingerprint = replyFingerprint, message = toSend}) --For newer versions of minecraft. This gives more control.
        end
      end
    end
  end
  
  
  
  
end

