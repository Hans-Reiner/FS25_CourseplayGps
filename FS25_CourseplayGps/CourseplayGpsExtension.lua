----------------------------------------------------------------------------------------------------
-- Courseplay Gps Extension (V1.0.0)
----------------------------------------------------------------------------------------------------
-- Purpose:  Courseplay Gps Extension
-- Authors:  Schluppe
--
-- Copyright (c) none - free to use 2025
--
-- History:	
--	V1.0.0 	13.10.2025 - Initial implementation
----------------------------------------------------------------------------------------------------
CourseplayGpsExtension = {}
CourseplayGpsExtension.LogLevel = 1	-- (0=Error, 1=Warning, 2=Info, 3=Debug)

-- Get Mod by Title as g_currentModDirectory nor g_currentModName isn't valid in specializations
for _, mod in pairs(g_modManager.mods) do
	if mod.title:upper() == "COURSEPLAY GPS EXTENSION" or mod.title:upper() == "COURSEPLAY GPS ERWEITERUNG" then
		if g_modIsLoaded[tostring(mod.modName)] then	
			CourseplayGpsExtension.modDirectory = mod.modDir
			CourseplayGpsExtension.modName = mod.modName
			break
		end
	end
end

-- Checks if the prerequisites and conditinos are present
function CourseplayGpsExtension.prerequisitesPresent(specializations)
	CourseplayGpsExtension.PrintModLog(3, "Prerequisites present" .. tostring(specializations))
	return SpecializationUtil.hasSpecialization(Drivable, specializations)
       and SpecializationUtil.hasSpecialization(CpAIWorker, specializations)
end

-- Initializes the Specialization
function CourseplayGpsExtension.initSpecialization()
	CourseplayGpsExtension.PrintModLog(3, "Initialize Specialization")
end

-- Register the Functions of the Specialization
function CourseplayGpsExtension.registerFunctions(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterFunctions " .. tostring(vehicleType))
	SpecializationUtil.registerFunction(vehicleType, "SteeringOnOff"			, CourseplayGpsExtension.SteeringOnOff)
	SpecializationUtil.registerFunction(vehicleType, "cpEonWaypointChange"		, CourseplayGpsExtension.cpEonWaypointChange)
	SpecializationUtil.registerFunction(vehicleType, "cpEonWaypointPassed"		, CourseplayGpsExtension.cpEonWaypointPassed)
end

-- Register the Event Listeners of the Specialization
function CourseplayGpsExtension.registerEventListeners(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterEventListeners")

	SpecializationUtil.registerEventListener(vehicleType, "onLoad"					, CourseplayGpsExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete"				, CourseplayGpsExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents"	, CourseplayGpsExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate"				, CourseplayGpsExtension)
end

-- Register Overwritten Function
function CourseplayGpsExtension.registerOverwrittenFunctions(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterOverwrittenFunctions")
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics"			, CourseplayGpsExtension.updateVehiclePhysics)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAIAutomaticSteeringState"	, CourseplayGpsExtension.getAIAutomaticSteeringState)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAIModeSelection"			, CourseplayGpsExtension.getAIModeSelection)
end

-- Event onLoad
function CourseplayGpsExtension:onLoad(savegame)
	CourseplayGpsExtension.PrintModLog(3, "onLoad")
	self.spec_cpGpsExtension = {}
	local spec = self.spec_cpGpsExtension
	spec.actionEvents = {}
	spec.steeringValue = 0
	spec.GpsActiveAvailable = false
	if self.isClient then
		spec.samples = {}
    	local specAS = self["spec_aiAutomaticSteering"]
		if specAS ~= nil then		
			spec.samples.engage = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.ai.automaticSteering.sounds", "engage", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
			spec.samples.disengage = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.ai.automaticSteering.sounds", "disengage", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
			spec.samples.lineEnd = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.ai.automaticSteering.sounds", "lineEnd", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		end
	end
end

---Called on deleting
function CourseplayGpsExtension:onDelete()
	CourseplayGpsExtension.PrintModLog(3, "onDelete")
	local spec = self.spec_cpGpsExtension
    if spec.samples ~= nil then
        g_soundManager:deleteSamples(spec.samples)
    end
end

-- Event On Register Action Events
function CourseplayGpsExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)    
	CourseplayGpsExtension.PrintModLog(3, "onRegisterActionEvents")
    if self.isClient then
        local spec = self.spec_cpGpsExtension
		self:clearActionEventsTable(spec.actionEvents)
		if self:getIsActiveForInput(true) and self.isActiveForInputIgnoreSelectionIgnoreAI then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.FS25_CourseplayGpsExtension_GPS_ONOFF, self, CourseplayGpsExtension.ToggleSteeringOnOff, false, true, false, true, nil)
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)
			g_inputBinding:setActionEventActive(actionEventId, false)
		end
    end
end

-- Event On Update
function CourseplayGpsExtension:onUpdate(dt)
	local spec = self.spec_cpGpsExtension
    local specFW = self["spec_FS25_Courseplay.cpAIFieldWorker"]

	if spec.ppc ~= nil and spec.GpsActive and spec.GpsActive == 1 then
		spec.ppc:update()		

	    local moveForwards = not spec.ppc:isReversing()
		local wX, _, wZ = spec.ppc:getGoalPointPosition()
		local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wX, 0, wZ)
		local lX, _, lZ = worldToLocal(self:getAISteeringNode(), wX, wY, wZ)

		if not moveForwards and self.spec_articulatedAxis ~= nil and
                self.spec_articulatedAxis.aiRevereserNode ~= nil then
            lX, _, lZ = worldToLocal(self.spec_articulatedAxis.aiRevereserNode, wX, wY, wZ)
        end

		if not moveForwards and self:getAIReverserNode() ~= nil then
            lX, _, lZ = worldToLocal(self:getAIReverserNode(), wX, wY, wZ)
        end

		local tX_2 = lX * 0.5
		local tZ_2 = lZ * 0.5

		local d1X, d1Z = tZ_2, -tX_2
		if lX > 0 then
			d1X, d1Z = -tZ_2, tX_2
		end

		local hit, _, f2 = MathUtil.getLineLineIntersection2D(tX_2, tZ_2, d1X, d1Z, 0,0, lX, 0)
		local rotTime = 0
		if hit and math.abs(f2) < 100000 then
			local radius = lX * f2
			rotTime = self:getSteeringRotTimeByCurvature(1 / radius)
			if self:getReverserDirection() < 0 then
				rotTime = -rotTime
			end
		end

		local speed = self.lastSpeedReal * 3600	-- m/ms => Km/h
		if (math.abs(speed) > 0.0) then
			rotTime = rotTime * math.min(1, math.max(5, (30 / speed)))  -- React slower at higher speeds
		else
			rotTime = 0
		end

		local targetRotTime
		if rotTime >= 0 then
			targetRotTime = math.min(rotTime, self.maxRotTime)
		else
			targetRotTime = math.max(rotTime, self.minRotTime)
		end

		if targetRotTime > spec.steeringValue then
			spec.steeringValue = math.min(spec.steeringValue + dt*self:getAISteeringSpeed(), targetRotTime)
		else
			spec.steeringValue = math.max(spec.steeringValue - dt*self:getAISteeringSpeed(), targetRotTime)
		end
	end

	spec.GpsActiveAvailable = self:getIsOnField() 
								and self:hasCpCourse() 
								and self:getCanStartCpFieldWork() 
								and specFW.driveStrategy ~= nil 
								and specFW.driveStrategy.fieldWorkCourse ~= nil 

	local toggleGpsButton = spec.actionEvents[InputAction.FS25_CourseplayGpsExtension_GPS_ONOFF]
	if toggleGpsButton ~= nil then
		if spec.GpsActiveAvailable then
			local currentText	
			if spec.GpsActive == 0 or spec.GpsActive == nil then
				currentText = g_i18n:getText("GPS_OFF", CourseplayGpsExtension.modName)
			else
				currentText = g_i18n:getText("GPS_ON", CourseplayGpsExtension.modName)
			end
			
			g_inputBinding:setActionEventActive(toggleGpsButton.actionEventId, true)
			g_inputBinding:setActionEventText(toggleGpsButton.actionEventId, currentText)
			g_inputBinding:setActionEventTextVisibility(toggleGpsButton.actionEventId, true)				
		else
			g_inputBinding:setActionEventTextVisibility(toggleGpsButton.actionEventId, false)
		end
	end
end

-- Overwritten Functions
-- Event On Update Vehicle Physics: Send steering control value to Vehicle 
function CourseplayGpsExtension:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
	-- CourseplayGpsExtension.PrintModLog(3, "updateVehiclePhysics")
	local spec = self.spec_cpGpsExtension
  	if spec.GpsActive and spec.GpsActive == 1 and spec.course ~= nil then
		if math.abs(axisSide) > 0.2 then
			spec.GpsActive = 0
		end

		if spec.steeringValue < 0 then
			axisSide = -spec.steeringValue / self.maxRotTime
		else
			axisSide = spec.steeringValue / self.minRotTime
		end

		spec.axisSide = axisSide
	else
		spec.axisSide = axisSide
	end

	-- call the original function to do the actual physics stuff
	local state, result = pcall(superFunc, self, axisForward, spec.axisSide, doHandbrake, dt)
	if not (state) then
		CourseplayGpsExtension.PrintModLog(1, "updateVehiclePhysics: " .. tostring(result))
		result = 0
	end
	return result
end

-- Override GPS Status for Dashboard
function CourseplayGpsExtension:getAIAutomaticSteeringState(superFunc)
	-- CourseplayGpsExtension.PrintModLog(1, "getAIAutomaticSteeringState")
	local spec = self.spec_cpGpsExtension
	-- call the original function to do get the AI Steering State
	local state, result = pcall(superFunc, self)
	if not (state) then
		CourseplayGpsExtension.PrintModLog(0, "getAIAutomaticSteeringState: " .. tostring(result))
		result = AIAutomaticSteering.STATE.DISABLED
	end

	if spec.GpsActiveAvailable then
		if result ~= AIAutomaticSteering.STATE.DISABLED then
			self:setAIAutomaticSteeringCourse(nil)	-- Empty the Giants AI Course. 
			-- This enables using the same key to activate auto steering, regardless using the Giants or CoursePlay tracking
			-- TBD: Maybe checking the same key binding or setting or any other good idea
		end

		if result == AIAutomaticSteering.STATE.DISABLED then
			result = AIAutomaticSteering.STATE.AVAILABLE
		end
	end

	if spec.GpsActive == 1 then
        result = AIAutomaticSteering.STATE.ACTIVE
	end
	return result
end

-- Override GPS Mode for Dashboard
function CourseplayGpsExtension:getAIModeSelection(superFunc)
	-- CourseplayGpsExtension.PrintModLog(1, "getAIModeSelection")
	local spec = self.spec_cpGpsExtension
	-- call the original function to do get the AI Steering State
	local state, result = pcall(superFunc, self)
	if not (state) then
		CourseplayGpsExtension.PrintModLog(0, "getAIModeSelection: " .. tostring(result))
		result = AIModeSelection.MODE.WORKER
	end

	if spec.GpsActiveAvailable then
        result = AIModeSelection.MODE.STEERING_ASSIST
	end
	return result
end

-- UI Callbacks --
-- Toggle GPS Tracking
function CourseplayGpsExtension.ToggleSteeringOnOff(self, actionName, inputValue, callbackState, isAnalog)
	self:SteeringOnOff()
end

-- PPC Callbacks --
-- Called on WayPoint changed
function CourseplayGpsExtension:cpEonWaypointChange(ix, course)
	CourseplayGpsExtension.PrintModLog(3, "onWaypointChange " .. tostring(ix))	
	local spec = self.spec_cpGpsExtension
	
	if spec.LastNodeInRow ~=nil and spec.LastNodeInRow == ix then
		CourseplayGpsExtension.PrintModLog(3, "updateVehiclePhysics: End of the row reached. Stop GPS")
		if spec.samples.lineEnd ~= nil then
			g_soundManager:playSample(spec.samples.lineEnd)
		end
		spec.GpsActive = 0
		if self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_ACTIVE then
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		end
	end
	if course:isLastWaypointIx(ix) then
		CourseplayGpsExtension.PrintModLog(3, "updateVehiclePhysics: End of the course reached. Stop GPS")
		if spec.samples.lineEnd ~= nil then
			g_soundManager:playSample(spec.samples.lineEnd)
		end
		spec.GpsActive = 0
		if self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_ACTIVE then
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		end
	end
end

-- Called on WayPoint passed
function CourseplayGpsExtension:cpEonWaypointPassed(ix, course)
	CourseplayGpsExtension.PrintModLog(3, "onWaypointPassed " .. tostring(ix))	
	local spec = self.spec_cpGpsExtension
	spec.LastNodeInRow = course:getNextRowStartIx(ix)
end

-- Local Functions --
-- Toggle Steering On / Off
function CourseplayGpsExtension:SteeringOnOff()
	CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff")	
	local spec = self.spec_cpGpsExtension
    local specFW = self["spec_FS25_Courseplay.cpAIFieldWorker"]

	spec.course = self:getFieldWorkCourse()
	if spec.course == nil then
		spec.GpsActive = 0			-- GPS Off
	else
		if spec.ppc == nil then
			spec.ppc = specFW.driveStrategy.ppc
			spec.ppc:registerListeners(self, 'cpEonWaypointPassed', 'cpEonWaypointChange')
			CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff Register PPC")	
		end

		local _, _, ClosestIdxInDirection, _ = spec.course:getNearestWaypoints(self:getAIDirectionNode())
		spec.ppc:setCourse(spec.course)
		spec.ppc:initialize(ClosestIdxInDirection)
		CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff Starting at Index " .. tostring(ClosestIdxInDirection))	

		if spec.GpsActive == 0 or spec.GpsActive == nil then
			spec.GpsActive = 1			-- GPS On
			spec.LastNodeInRow = nil
		else
			spec.GpsActive = 0			-- GPS Off
		end
        if self.isClient then
			if spec.GpsActive == 1 then
				if spec.samples.engage ~= nil then
	                g_soundManager:playSample(spec.samples.engage)
				end
            else
				if spec.samples.disengage ~= nil then
	                g_soundManager:playSample(spec.samples.disengage)
				end
            end
		end
	end
end

-- Print into Log file
function CourseplayGpsExtension.PrintModLog(severity, text)
	local level = CourseplayGpsExtension.LogLevel
	if level >= severity then		
		local prefix
		if severity == 0 then 		-- Error
			prefix = "ERROR  :"
		elseif severity == 1 then 	-- Warning
			prefix = "WARNING:"
		elseif severity == 2 then 	-- Info
			prefix = "INFO   :"
		elseif severity == 3 then 	-- Debug
			prefix = "DEBUG  :"
		else
			prefix = "       :"
		end
		
		print("FS25_CourseplayGps " .. prefix .. tostring(text))
	end
end
