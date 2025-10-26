----------------------------------------------------------------------------------------------------
-- Courseplay Gps Extension (V1.0.1)
----------------------------------------------------------------------------------------------------
-- Purpose:  Courseplay Settings Handling
-- Authors:  Schluppe
--
-- Copyright (c) none - free to use 2025
--
-- History:
--  V1.0.0  18.10.2025 - Initial implementation, Adding Settings to CP Vehicle settings screen
--  V1.0.1  24.10.2025 - Options to control cruise control and deactivation of automatic steering
----------------------------------------------------------------------------------------------------
CourseplayGpsSettingsUtil = {}
local CourseplayGpsSettingsUtil_mt = Class(CourseplayGpsSettingsUtil)
CourseplayGpsSettingsUtil.SettingRegistered = false

-- Create a new Class to handle the Settings
function CourseplayGpsSettingsUtil.new(vehicle)
	CourseplayGpsExtension.PrintModLog(3, "Create new CourseplayGpsSettingsUtil")
	local self = setmetatable({}, CourseplayGpsSettingsUtil_mt)
	self.vehicle = vehicle
	self.settingGroups = {}
	return self
end

-- Create Settings Parameters
function CourseplayGpsSettingsUtil:CreateSettingsParameters(uniqueID)
	local parameters = {}
	uniqueID = uniqueID + 1
	table.insert(parameters, self:CreateSettingsParameter(uniqueID, "AIParameterBooleanSetting" , "cpGpsDisableGiantsAiSteering", true))
	uniqueID = uniqueID + 1
	table.insert(parameters, self:CreateSettingsParameter(uniqueID, "AIParameterSettingList" , "cpGpsHidePathTime", 3, 0, 10))
	local parameter = self:CreateSettingsParameter(uniqueID, "AIParameterSettingList" , "cpGpsPathDisplay", 4, 0, 4)
	if parameter ~= nil then
		table.insert(parameter.values, 0)
		table.insert(parameter.texts, g_i18n:getText("ShowCourse_Deactivated"))
		table.insert(parameter.values, 1)
		table.insert(parameter.texts, g_i18n:getText("ShowCourse_StartStop"))
		table.insert(parameter.values, 2)
		table.insert(parameter.texts, g_i18n:getText("ShowCourse_All"))
		table.insert(parameter.values, 3)
		table.insert(parameter.texts, g_i18n:getText("ShowCourse_CurrentWaypoint"))
		table.insert(parameter.values, 4)
		table.insert(parameter.texts, g_i18n:getText("ShowCourse_Unchanged"))
		table.insert(parameters, parameter)
	end

	uniqueID = uniqueID + 1
	local parameter = self:CreateSettingsParameter(uniqueID, "AIParameterSettingList" , "cpGpsDisableCruiseControl", 1, 0, 3)
	if parameter ~= nil then
		table.insert(parameter.values, 0)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_Never"))
		table.insert(parameter.values, 1)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_EndOfRow"))
		table.insert(parameter.values, 2)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_OnConnectionPoints"))
		table.insert(parameter.values, 3)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_EndOfCourse"))
		table.insert(parameters, parameter)
	end

	uniqueID = uniqueID + 1
	local parameter = self:CreateSettingsParameter(uniqueID, "AIParameterSettingList" , "cpGpsDisableSteering", 1, 0, 3)
	if parameter ~= nil then
		table.insert(parameter.values, 0)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_Never"))
		table.insert(parameter.values, 1)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_EndOfRow"))
		table.insert(parameter.values, 2)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_OnConnectionPoints"))
		table.insert(parameter.values, 3)
		table.insert(parameter.texts, g_i18n:getText("WpTrigger_EndOfCourse"))		
		table.insert(parameters, parameter)
	end

	CourseplayGpsExtension.PrintModLog(3, "%s parameters for settings created.", #parameters)
	return parameters
end

-- Adding text to FS25_Courseplay mod texts (required for the setting frames)
function CourseplayGpsSettingsUtil:AddTextsToCourseplay()
	CourseplayGpsExtension.PrintModLog(3, "Adding Texts to Courseplay")
	
	local mt = getmetatable(g_i18n)
	if mt and type(mt) == 'table' then
		local cpTexts = mt.__index.modEnvironments.FS25_Courseplay
		local l10nCount = 0	
		for tag, text in pairs(g_i18n.texts) do
			if tag and string.sub(tag, 1, 19) == "FS25_CourseplayGps_" then		
				cpTexts.texts[tag] = text	
				l10nCount = l10nCount + 1
			end
		end
		CourseplayGpsExtension.PrintModLog(3, "Adding Texts to CP completed. %s texts added.", l10nCount)		
	end
end

-- Create Setting for Vehicle
function CourseplayGpsSettingsUtil:CreateVehicleSettings()
	CourseplayGpsExtension.PrintModLog(3, "Create Settings for Vehicle %s", self.vehicle)
	local specVS = self.vehicle["spec_FS25_Courseplay.cpVehicleSettings"]
	local cpVehicleSettings = nil
	-- Get cpVehicleSettings from existing CP Settings 
	if specVS and specVS.settings and #specVS.settings > 1 then
		cpVehicleSettings = specVS.settings[1].class
	else
		CourseplayGpsExtension.PrintModLog(1, "No CP Settings for the Vehicle found. Unable to attach GPS Settings.")
		return
	end

	if cpVehicleSettings ~= nil then
		for i, settingGroup in pairs(self.settingGroups) do
			CourseplayGpsExtension.PrintModLog(3, "Checking Group %s (%s)",i , settingGroup)
			for _, setting in pairs(settingGroup.elements) do
				local settingClone = setting:clone(self.vehicle, cpVehicleSettings)
				table.insert(specVS.settings, settingClone)
				specVS[settingClone:getName()] = settingClone
				CourseplayGpsExtension.PrintModLog(3, "Adding setting %s", setting:getName())
			end
		end
	end 
end

-- Create Setting Setup for the Courseplay Gps Extension  
function CourseplayGpsSettingsUtil:CreateSettingSetup()
	CourseplayGpsExtension.PrintModLog(3, "Create Settings for CP Menu %s", self.vehicle)
	
	local specVS = self.vehicle["spec_FS25_Courseplay.cpVehicleSettings"]
	local cpVehicleSettings = nil
	-- Get cpVehicleSettings from existing CP Settings 
	if specVS and specVS.settings and #specVS.settings > 1 then
		cpVehicleSettings = specVS.settings[1].class
	else
		CourseplayGpsExtension.PrintModLog(1, "No CP Settings for the Vehicle found. Unable to attach GPS Settings ")
		return
	end

	if cpVehicleSettings ~= nil then
		local parameters = self:CreateSettingsParameters(#cpVehicleSettings.settings)
		CourseplayGpsExtension.PrintModLog(3, "Creating %s settings", #parameters)
		if #parameters > 0 then
			local subSettings = nil
			for _, subTitle in pairs(cpVehicleSettings.settingsBySubTitle) do
				if subTitle.title == "FS25_CourseplayGps_GPS_TRACKING" then
					subSettings = subTitle
				end 
			end
			if subSettings == nil then
				subSettings = {
					title = "FS25_CourseplayGps_GPS_TRACKING",
					elements = {},
					isDisabledFunc = nil,
					isVisibleFunc = nil,
					isExpertModeOnly = false,
					class = cpVehicleSettings
				}
				CourseplayGpsExtension.PrintModLog(3, "Creating subTitle %s", subSettings.title)
				-- Always add the subSetting into the specific vehicle
				table.insert(cpVehicleSettings.settingsBySubTitle, subSettings)
			end

			table.insert(self.settingGroups, subSettings)
			for _, parameter in pairs(parameters) do
				CourseplayGpsExtension.PrintModLog(3, "Create Setting %s", parameter.name)
				local setting = self:CreateDynamicObject(parameter.classType, parameter, nil, cpVehicleSettings)
				CourseplayGpsExtension.PrintModLog(3, "Setting created %s", setting)
				if setting ~= nil and not CourseplayGpsSettingsUtil.SettingRegistered then
					cpVehicleSettings[parameter.name] = setting
					table.insert(cpVehicleSettings.settings, setting)
					table.insert(subSettings.elements, setting)
				end
			end
		end
		CourseplayGpsSettingsUtil.SettingRegistered = true
		CourseplayGpsExtension.PrintModLog(3, "Registering %s settings completed.", (#parameters))
	end
end

-- Create Settings Parameters
function CourseplayGpsSettingsUtil:CreateSettingsParameter(uniqueID, classType, name, defaultValue, min, max)
	CourseplayGpsExtension.PrintModLog(3, "Creating parameter %s of type %s", name, classType)

	local rootKey = "FS25_CourseplayGps_Vehicle_setting_"
	local parameter = {}
	parameter.uniqueID = uniqueID
	parameter.classType = "FS25_Courseplay." .. classType
	parameter.name = name
	parameter.setupName = rootKey .. name
	parameter.title = parameter.setupName .. "_title"
	parameter.tooltip = parameter.setupName .. "_tooltip"

	if classType == "AIParameterBooleanSetting" then
		parameter.defaultBool = defaultValue
	else
		parameter.default = defaultValue
	end

	parameter.textInputAllowed = false
	parameter.isUserSetting = false
	parameter.isExpertModeOnly = false

	parameter.min = min
	parameter.max = max

	parameter.incremental = 1
	parameter.precision = 2
	parameter.textStr = nil
	parameter.unit = nil
	parameter.vehicleConfiguration = nil
	parameter.isDisabledFunc = nil
	parameter.isVisibleFunc = nil
	parameter.setDefaultFunc = nil
	parameter.positionParameterType = nil
	parameter.values = {}
	parameter.texts = {}
	parameter.callbacks = {}
	parameter.callbacks.onChangeCallbackStr = nil
	return parameter
end

function CourseplayGpsSettingsUtil:GetClassObject(className)
	local status, classObject = xpcall(
		function()
			local parts = string.split(className, ".")
			local currentTable = _G[parts[1]]
			if type(currentTable) ~= "table" then
				return nil
			end
			for i = 2, #parts do
				currentTable = currentTable[parts[i]]
				if type(currentTable) ~= "table" then
					return nil
				end
			end
			return currentTable
		end,
		function(err)
			CourseplayGpsExtension.PrintModLog(0, "Error GetClassObject: %s", err)
			return nil
		end
	)

	if status then
		return classObject
	else
		return nil
	end
end

function CourseplayGpsSettingsUtil:CreateDynamicObject(classType, ...)
	CourseplayGpsExtension.PrintModLog(3, "CreateDynamicObject: %s", classType)
	local classObject = self:GetClassObject(classType)
	if classObject == nil then
		CourseplayGpsExtension.PrintModLog(0, "Setting class %s not found!", classType)
		return nil
	end
	if classObject.new then
		return classObject.new(...)
	else
		return classObject(...)
	end
end
