----------------------------------------------------------------------------------------------------
-- Courseplay Gps Extension (V1.0.3)
----------------------------------------------------------------------------------------------------
-- Purpose:  Courseplay Gps Extension
-- Authors:  Schluppe
--
-- Copyright (c) none - free to use 2025
--
-- History:
--  V1.0.0  13.10.2025 - Initial implementation
--  V1.0.1  15.10.2025 - Change Track visibility when auto steering is active
--  V1.0.2  18.10.2025 - Adding Parameter to control the behavior, Multi-Player
--  V1.0.3  26.10.2025 - Fix an issue linked to steering wheel not centered. 
--                     - Options to control cruise control and deactivation of automatic steering
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
	CourseplayGpsExtension.PrintModLog(3, "Prerequisites present %s", specializations)
	return SpecializationUtil.hasSpecialization(Drivable, specializations)
       and SpecializationUtil.hasSpecialization(CpAIWorker, specializations)
end

-- Initializes the Specialization
function CourseplayGpsExtension.initSpecialization()
	CourseplayGpsExtension.PrintModLog(3, "Initialize Specialization")
	CourseplayGpsExtension.LoadScripts()
end

-- Register the Functions of the Specialization
function CourseplayGpsExtension.registerFunctions(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterFunctions %s", vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "SteeringOnOff"			, CourseplayGpsExtension.SteeringOnOff)
	SpecializationUtil.registerFunction(vehicleType, "cpEonWaypointChange"		, CourseplayGpsExtension.cpEonWaypointChange)
	SpecializationUtil.registerFunction(vehicleType, "cpEonWaypointPassed"		, CourseplayGpsExtension.cpEonWaypointPassed)
end

-- Register the Event Listeners of the Specialization
function CourseplayGpsExtension.registerEventListeners(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterEventListeners")

    SpecializationUtil.registerEventListener(vehicleType, "onPreLoad"				, CourseplayGpsExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad"					, CourseplayGpsExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete"				, CourseplayGpsExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents"	, CourseplayGpsExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate"				, CourseplayGpsExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick"			, CourseplayGpsExtension)
end

-- Register Overwritten Function
function CourseplayGpsExtension.registerOverwrittenFunctions(vehicleType)
	CourseplayGpsExtension.PrintModLog(3, "RegisterOverwrittenFunctions")
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "setSteeringInput"				, CourseplayGpsExtension.setSteeringInput)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAIAutomaticSteeringState"	, CourseplayGpsExtension.getAIAutomaticSteeringState)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAIModeSelection"			, CourseplayGpsExtension.getAIModeSelection)
end


-- Event onPreLoad
function CourseplayGpsExtension:onPreLoad(savegame)
	CourseplayGpsExtension.PrintModLog(3, "onPreLoad")
	self.spec_cpGpsExtension = {}
	local spec = self.spec_cpGpsExtension
	spec.SettingUtil = CourseplayGpsSettingsUtil.new(self)
end

-- Event onLoad
function CourseplayGpsExtension:onLoad(savegame)
	CourseplayGpsExtension.PrintModLog(3, "onLoad")	
	local spec = self.spec_cpGpsExtension
	spec.steeringLastEnableTime = -math.huge
	spec.lastSteeringInputValue = 0

	--- Attach to Courseplay
	spec.SettingUtil:AddTextsToCourseplay()
	spec.SettingUtil:CreateSettingSetup()
	spec.SettingUtil:CreateVehicleSettings()

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
    if spec and spec.samples ~= nil then
        g_soundManager:deleteSamples(spec.samples)
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
			-- Limit steering request to prevent over-shooting
			if self.isServer then
				rotTime = rotTime * math.min(1, math.max(5, (20 / speed)))
			else
				-- Clients in MP do react slower
				rotTime = rotTime * math.min(0.5, math.max(5, (10 / speed)))
			end
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

		self:setSteeringInput(spec.steeringValue, true, InputDevice.CATEGORY.UNKNOWN)
	end

	spec.GpsActiveAvailable = self:getIsOnField()
								and self:hasCpCourse()
								and self:getCanStartCpFieldWork()

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

-- Event On Update Tick
function CourseplayGpsExtension:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
   	if self.isClient then
		local spec = self.spec_cpGpsExtension
		if spec.HidePathTime then
			spec.HidePathTime = spec.HidePathTime - dt
			if spec.HidePathTime < 0 then
				spec.HidePathTime = nil
				self:getCpSettings().showCourse:setValue(0)
			end
		end
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


-- Overwritten Functions
-- Override Steering Input to deactivate GPS uppon manual steering attempt and apply steering command 
function CourseplayGpsExtension:setSteeringInput(superFunc, inputValue, isAnalog, deviceCategory)
	local spec = self.spec_cpGpsExtension
	if spec.GpsActive and spec.GpsActive == 1 then
		-- CourseplayGpsExtension.PrintModLog(4, "setSteeringInput deviceCategory=%s inputValue=%s", deviceCategory, inputValue) 
		if deviceCategory == InputDevice.CATEGORY.KEYBOARD_MOUSE then
			CourseplayGpsExtension.PrintModLog(3, "setSteeringInput Deactivate GPS by Keyboard.") 
			self:SteeringOnOff(0)	-- GPS Off
		elseif deviceCategory == InputDevice.CATEGORY.UNKNOWN then
			-- Automatic steering
			inputValue = -inputValue
		elseif g_time - spec.steeringLastEnableTime > 2000 then
			local steerDiff = inputValue - spec.lastSteeringInputValue
			-- CourseplayGpsExtension.PrintModLog(4, "setSteeringInput deviceCategory=%s inputValue=%s steeringDifference=%s", deviceCategory, inputValue, steerDiff) 
			if math.abs(steerDiff) > 0.2 then
				CourseplayGpsExtension.PrintModLog(3, "setSteeringInput Deactivate GPS by Steering.") 
				self:SteeringOnOff(0)	-- GPS Off
			end
			return	-- When GPS tracking is active, we are not calling the super-function to ignore the manual steering command
		else
			spec.lastSteeringInputValue = inputValue
		end		
	else
		spec.lastSteeringInputValue = inputValue
	end
	return superFunc(self, inputValue, isAnalog, deviceCategory)
end

-- Override GPS Status for Dashboard
function CourseplayGpsExtension:getAIAutomaticSteeringState(superFunc)
	local spec = self.spec_cpGpsExtension
	-- call the original function to do get the AI Steering State
	local state, result = pcall(superFunc, self)
	if not (state) then
		CourseplayGpsExtension.PrintModLog(0, "getAIAutomaticSteeringState: %s", result)
		result = AIAutomaticSteering.STATE.DISABLED
	end

	if spec.GpsActiveAvailable then
		if result ~= AIAutomaticSteering.STATE.DISABLED and self:getCpSettings().cpGpsDisableGiantsAiSteering:getValue() then
			self:setAIAutomaticSteeringCourse(nil)	-- Empty the Giants AI Course.
			local warning = g_i18n:getText("DisableGiantsAiSteering_warning")
			if warning ~= nil then
				g_currentMission:showBlinkingWarning(warning, 5000)
			end
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
	local spec = self.spec_cpGpsExtension
	-- call the original function to do get the AI Steering State
	local state, result = pcall(superFunc, self)
	if not (state) then
		CourseplayGpsExtension.PrintModLog(0, "getAIModeSelection: %s", result)
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

-- Public Functions --
-- PPC Callback: Called on WayPoint changed
function CourseplayGpsExtension:cpEonWaypointChange(ix, course)
	CourseplayGpsExtension.PrintModLog(4, "onWaypointChange %s", ix)
	local spec = self.spec_cpGpsExtension

	if spec.SetPpcNormalDistanceIndex ~= nil and ix == spec.SetPpcNormalDistanceIndex then
		spec.SetPpcNormalDistanceIndex = nil
		spec.ppc:setNormalLookaheadDistance()
		CourseplayGpsExtension.PrintModLog(3, "onWaypointChange: PPC Normal Distance")
	end
	if spec.SetPpcShortDistanceIndex ~= nil and ix == spec.SetPpcShortDistanceIndex then
		spec.SetPpcShortDistanceIndex = nil
		spec.ppc:setShortLookaheadDistance()
		spec.SetPpcNormalDistanceIndex = ix + 3
		CourseplayGpsExtension.PrintModLog(3, "onWaypointChange: PPC Short Distance")
	end

	-- Last point in the row
	local disableSteering = self:getCpSettings().cpGpsDisableSteering:getValue()
	local disableCruiseCtrl = self:getCpSettings().cpGpsDisableCruiseControl:getValue()
	if spec.LastNodeInRow ~=nil and spec.LastNodeInRow == ix then 
		if disableSteering == 1 then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: End of the row reached. Stop GPS")
			self:SteeringOnOff(2)	-- GPS Off
		else
			spec.SetPpcShortDistanceIndex = ix + 1
		end
		if disableCruiseCtrl == 1 and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_ACTIVE then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: End of the row reached. Stop Cruise Control")
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		end		
	end

	-- WP is on connecting path or headland turning 
	if course:isOnConnectingPath(ix) or course:isHeadlandTurnAtIx(ix) then 
		if disableSteering >= 1 and disableSteering <= 2 then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: Connecting path reached. Stop GPS")
			self:SteeringOnOff(2)	-- GPS Off
		else
			spec.SetPpcShortDistanceIndex = ix + 1
		end
		if disableCruiseCtrl >= 1 and disableCruiseCtrl <= 2 and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_ACTIVE then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: Connecting path reached. Stop Cruise Control")
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		end		
	end

	-- End of course reached
	if course:isLastWaypointIx(ix) then
		if disableCruiseCtrl >= 1 and disableCruiseCtrl <= 3 then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: End of the course reached. Stop GPS")
			self:SteeringOnOff(2)	-- GPS Off
		end
		if disableCruiseCtrl >= 1 and disableCruiseCtrl <= 3  and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_ACTIVE then
			CourseplayGpsExtension.PrintModLog(2, "onWaypointChange: End of the course reached. Stop Cruise Control")
			self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		end		
	end

	course:setCurrentWaypointIx(ix)
	self:updateCpCourseDisplayVisibility()
end

-- PPC Callback: Called on WayPoint passed
function CourseplayGpsExtension:cpEonWaypointPassed(ix, course)
	CourseplayGpsExtension.PrintModLog(4, "onWaypointPassed %s", ix)
	local spec = self.spec_cpGpsExtension
	spec.LastNodeInRow = course:getNextRowStartIx(ix)
end

-- Toggle Steering On / Off
-- State: nil=Toggle 0=Off, 1=On, 2=Off end reached
function CourseplayGpsExtension:SteeringOnOff(state)
	CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff (%s)", state)
	local spec = self.spec_cpGpsExtension
    local specFW = self["spec_FS25_Courseplay.cpAIFieldWorker"]

	spec.course = self:getFieldWorkCourse()
	if spec.course == nil then
		spec.GpsActive = 0		-- GPS Off
	else
		if spec.ppc == nil then
			spec.ppc = spec.SettingUtil:CreateDynamicObject("FS25_Courseplay.PurePursuitController", self)
			CourseplayGpsExtension.PrintModLog(3, "Created PPC (%s)", spec.ppc)
			spec.ppc:registerListeners(self, 'cpEonWaypointPassed', 'cpEonWaypointChange')
			CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff Register PPC")
		end

		local displayMode = self:getCpSettings().cpGpsPathDisplay:getValue()
		if (state == nil and (spec.GpsActive == 0 or spec.GpsActive == nil)) or
		   (state ~= nil and state == 1)
		then
			local _, _, ClosestIdxInDirection, _ = spec.course:getNearestWaypoints(self:getAIDirectionNode())
			spec.ppc:setCourse(spec.course)
			spec.ppc:initialize(ClosestIdxInDirection)
			spec.ppc:setShortLookaheadDistance()
			spec.SetPpcNormalDistanceIndex = ClosestIdxInDirection + 2
			CourseplayGpsExtension.PrintModLog(3, "SteeringOnOff Starting at Index %s" , ClosestIdxInDirection)
			spec.LastNodeInRow = nil

			if displayMode >= 0 and displayMode < 4 then
				self:getCpSettings().showCourse:setValue(displayMode)
			end

			spec.CourseVisibility = self:getCpSettings().showCourse:getValue()
			local timeToHide = self:getCpSettings().cpGpsHidePathTime:getValue()
			if timeToHide > 0 then
				spec.HidePathTime = 1000 * timeToHide
			end
			spec.steeringLastEnableTime = g_time
			spec.GpsActive = 1 		-- GPS On
	        if self.isClient and spec.samples.engage ~= nil then
				g_soundManager:playSample(spec.samples.engage)
			end
		else
			spec.GpsActive = 0		-- GPS Off
			spec.HidePathTime = nil
			if spec.CourseVisibility then
				self:getCpSettings().showCourse:setValue(spec.CourseVisibility)
			end
	        if self.isClient then
				if (state and state == 2) then
					if spec.samples.lineEnd ~= nil then
						g_soundManager:playSample(spec.samples.lineEnd)
					end
				else
					if spec.samples.disengage ~= nil then
						g_soundManager:playSample(spec.samples.disengage)
					end
				end
			end
		end
	end
end

-- Local Functions --

-- Print into Log file
function CourseplayGpsExtension.PrintModLog(severity, text, ...)
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

		print("FS25_CourseplayGps " .. prefix .. string.format(text , ...))
	end
end

-- Load additional Scripts
function CourseplayGpsExtension.LoadScripts()
	local scriptFolder = CourseplayGpsExtension.modDirectory
	CourseplayGpsExtension.PrintModLog(3, "Loading scripts from %s", scriptFolder)

	source(scriptFolder .. "CourseplayGpsSettingsUtil.lua")
end
