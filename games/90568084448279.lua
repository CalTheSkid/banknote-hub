--[[
    Game Config - Sniper Arena (PlaceId: 90568084448279)
]]

return {
    Pages = {
        {
            Name = "combat",
            Sections = {
                {
                    Name = "Silent Aim",
                    Side = 1,
                    Elements = {
                        {Type = "Toggle", Name = "Enable Silent Aim", Flag = "SilentAim", Default = false},
                        {Type = "Dropdown", Name = "Target Part", Flag = "SilentHitPart", Items = {"Head", "Torso", "HumanoidRootPart"}, Default = "Head"},
                        {Type = "Slider", Name = "FOV Radius", Flag = "SilentFOV", Min = 10, Max = 800, Default = 150, Decimals = 1, Suffix = "px"},
                        {Type = "Slider", Name = "Hit Chance", Flag = "SilentHitChance", Min = 0, Max = 100, Default = 100, Decimals = 1, Suffix = "%"},
                        {Type = "Toggle", Name = "Show FOV Circle", Flag = "ShowFOVCircle", Default = false},
                        {Type = "Label", Name = "FOV Color", Colorpicker = {Name = "FOV Color", Flag = "FOVCircleColor", Default = Color3.fromRGB(255, 255, 255)}},
                        {Type = "Toggle", Name = "Wall Check", Flag = "WallCheck", Default = true},
                        {Type = "Toggle", Name = "Team Check", Flag = "TeamCheck", Default = true},
                    }
                },
                {
                    Name = "Gun Mods",
                    Side = 2,
                    Elements = {
                        {Type = "Toggle", Name = "Auto Shoot", Flag = "AutoShoot", Default = false},
                        {Type = "Slider", Name = "Auto Shoot Delay", Flag = "AutoShootDelay", Min = 0.1, Max = 5, Default = 1, Decimals = 1, Suffix = "s"},
                        {Type = "Toggle", Name = "Quick Scope", Flag = "QuickScope", Default = false},
                        {Type = "Toggle", Name = "No Recoil", Flag = "NoRecoil", Default = false},
                    }
                }
            }
        },
        {
            Name = "misc",
            Sections = {
                {
                    Name = "Movement",
                    Side = 1,
                    Elements = {
                        {Type = "Toggle", Name = "Speed Hack", Flag = "SpeedHack", Default = false},
                        {Type = "Slider", Name = "Speed Value", Flag = "SpeedValue", Min = 16, Max = 250, Default = 50, Decimals = 1, Suffix = " studs/s"},
                        {Type = "Toggle", Name = "Jump Power Hack", Flag = "JumpHack", Default = false},
                        {Type = "Slider", Name = "Jump Power Value", Flag = "JumpPower", Min = 50, Max = 300, Default = 50, Decimals = 1},
                        {Type = "Toggle", Name = "Infinite Jump", Flag = "InfJump", Default = false},
                        {Type = "Toggle", Name = "Fly", Flag = "FlyEnabled", Default = false},
                        {Type = "Slider", Name = "Fly Speed", Flag = "FlySpeed", Min = 1, Max = 300, Default = 50, Decimals = 1, Suffix = " studs/s"},
                        {Type = "Toggle", Name = "No Clip", Flag = "NoClip", Default = false},
                    }
                },
                {
                    Name = "Exploits",
                    Side = 2,
                    Elements = {
                        {Type = "Toggle", Name = "Anti AFK", Flag = "AntiAFK", Default = true},
                        {Type = "Button", Name = "Rejoin Server", Callback = function()
                            if getgenv().SniperArena_Rejoin then
                                pcall(getgenv().SniperArena_Rejoin)
                            end
                        end},
                        {Type = "Button", Name = "Server Hop", Callback = function()
                            if getgenv().SniperArena_ServerHop then
                                pcall(getgenv().SniperArena_ServerHop)
                            end
                        end},
                        {Type = "Textbox", Name = "Teleport to Player", Flag = "TpToPlayer", Placeholder = "Username", Finished = true, Callback = function(value)
                            if getgenv().SniperArena_TpToPlayer then
                                pcall(getgenv().SniperArena_TpToPlayer, value)
                            end
                        end},
                    }
                }
            }
        },
        {
            Name = "visuals",
            Sections = {
                {
                    Name = "ESP",
                    Side = 1,
                    Elements = {
                        {Type = "Toggle", Name = "Player ESP", Flag = "PlayerESP", Default = false},
                        {Type = "Toggle", Name = "Box ESP", Flag = "BoxESP", Default = false},
                        {Type = "Toggle", Name = "Name ESP", Flag = "NameESP", Default = false},
                        {Type = "Toggle", Name = "Health Bar", Flag = "HealthBar", Default = false},
                        {Type = "Toggle", Name = "Tracers", Flag = "Tracers", Default = false},
                        {Type = "Dropdown", Name = "Tracer Origin", Flag = "TracerOrigin", Items = {"Bottom", "Center", "Mouse"}, Default = "Bottom"},
                        {Type = "Label", Name = "ESP Color", Colorpicker = {Name = "ESP Color", Flag = "ESPColor", Default = Color3.fromRGB(255, 0, 0)}},
                        {Type = "Toggle", Name = "Chams", Flag = "Chams", Default = false},
                        {Type = "Label", Name = "Chams Color", Colorpicker = {Name = "Chams Color", Flag = "ChamsColor", Default = Color3.fromRGB(128, 0, 255)}},
                    }
                },
                {
                    Name = "World",
                    Side = 2,
                    Elements = {
                        {Type = "Toggle", Name = "Fullbright", Flag = "Fullbright", Default = false},
                        {Type = "Slider", Name = "Field of View", Flag = "FOV", Min = 30, Max = 120, Default = 70, Decimals = 1, Suffix = "°"},
                        {Type = "Toggle", Name = "No Fog", Flag = "NoFog", Default = false},
                    }
                }
            }
        },
        {
            Name = "players",
            Sections = {
                {
                    Name = "Targeting",
                    Side = 1,
                    Elements = {
                        {Type = "Dropdown", Name = "Aim Target", Flag = "AimTarget", Items = {"Closest to Cursor", "Closest Distance", "Lowest Health", "Random"}, Default = "Closest to Cursor"},
                        {Type = "Slider", Name = "Max Distance", Flag = "MaxAimDist", Min = 50, Max = 2000, Default = 500, Decimals = 1, Suffix = " studs"},
                    }
                },
                {
                    Name = "Player Info",
                    Side = 2,
                    Elements = {
                        {Type = "Textbox", Name = "Spectate Player", Flag = "SpectatePlayer", Placeholder = "Username", Finished = true, Callback = function(value)
                            if getgenv().SniperArena_SpectatePlayer then
                                pcall(getgenv().SniperArena_SpectatePlayer, value)
                            end
                        end},
                        {Type = "Button", Name = "Stop Spectating", Callback = function()
                            if getgenv().SniperArena_StopSpectating then
                                pcall(getgenv().SniperArena_StopSpectating)
                            end
                        end},
                    }
                }
            }
        }
    }
}
