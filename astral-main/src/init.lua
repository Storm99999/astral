--[[

                       /$$                        /$$
                      | $$                       | $$
  /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$  /$$$$$$ | $$
 |____  $$ /$$_____/|_  $$_/   /$$__  $$|____  $$| $$
  /$$$$$$$|  $$$$$$   | $$    | $$  \__/ /$$$$$$$| $$
 /$$__  $$ \____  $$  | $$ /$$| $$      /$$__  $$| $$
|  $$$$$$$ /$$$$$$$/  |  $$$$/| $$     |  $$$$$$$| $$
 \_______/|_______/    \___/  |__/      \_______/|__/
                                                     
                                                     
                                                     
	@name: init.lua (LocalScript)
	@version: 1.0.0
	@author: Celeste Softworks © 2025
	@date: 05/08/25
	@description: Automatically initializes all ModuleScripts in the folder.
]]

local modulesFolder = script.Parent.Parent.controllers or nil;
local signed = {};

local function init(folder)
	assert(folder and folder:IsA("Instance"), "Expected a folder instance");

	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			local ok, module = pcall(require, moduleScript);
			if ok and type(module) == "table" and type(module.Start) == "function" then
				local signature = game:GetService("HttpService"):GenerateGUID(false);
				print("[astral @ init] Signed ", moduleScript.Name, "|", signature);
				signed[signature] = type(module.Stop) == "function" and module.Stop or nil;
				task.spawn(module.Start);
			end;
		end;
	end;
end;

local function deinit(signature)
	signed[signature]();
end;

init(modulesFolder);
