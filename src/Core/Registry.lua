---@type string, table
local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type Fader
local fader = addon.Core.Fader
local modules = {}
---@type Config
local db

---@class Registry
local M = {}
addon.Core.Registry = M

---Adds a module. Called at file scope, so the load order in the toc is the order the
---options panel lists them in.
---@param module FadeModule
---@return FadeModule
function M:Add(module)
	modules[#modules + 1] = module

	return module
end

---Every module, in load order.
---@return FadeModule[]
function M:GetAll()
	return modules
end

---The saved variables. Read on demand rather than handed out by Init, because the options
---panel is built a step earlier, while Config is still merging the defaults.
---@return Config
function M:Vars()
	db = db or mini:GetSavedVars()

	return db
end

---Whether the player has fading switched on for this module.
---@param key string
---@return boolean
function M:IsEnabled(key)
	return self:Vars().Frames[key]
end

---@param key string
---@param enabled boolean
function M:SetEnabled(key, enabled)
	self:Vars().Frames[key] = enabled
	fader:Refresh()
	self:Refresh()
end

---Hands every module the frames it fades. Runs again on each loading screen, because a
---frame the client had not built yet may be there by the next one.
function M:Register()
	for i = 1, #modules do
		local module = modules[i]

		if module.Register then
			module:Register()
		end
	end
end

---Re-reads settings across every module. Cheap enough to call after any config change.
function M:Refresh()
	for i = 1, #modules do
		local module = modules[i]

		if module.Refresh then
			module:Refresh()
		end
	end
end

function M:Init()
	for i = 1, #modules do
		local module = modules[i]

		if module.Init then
			module:Init()
		end
	end
end

---@class FadeModule
---@field Key string the db.Frames key this module's setting lives under
---@field Title string the checkbox label in the options panel
---@field Tooltip string the checkbox tooltip
---@field Default boolean whether fading is on out of the box
---@field Defaults table? further saved variable defaults, merged into the root
---@field Options FadeModuleOptions? a settings section of the module's own
---@field Init fun(self: FadeModule)? one-off setup, run once the saved variables are up
---@field Register fun(self: FadeModule)? hands its frames to the fader, run on each loading screen
---@field Refresh fun(self: FadeModule)? re-reads settings, run after any config change

---@class FadeModuleOptions
---@field Title string the divider title above the section
---@field Settings CheckboxOptions[] checkboxes, each with its own GetValue and SetValue
