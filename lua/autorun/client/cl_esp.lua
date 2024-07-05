include("config.lua")

local esp_enabled = false
local esp_entities = { "prop_vehicle_*", "player", "npc_*" }
local max_distance_name = 1000
local max_distance_line = 10000

local function IsAllowed(ply)
    local usergroup = ply:GetNWString("usergroup")
    local steamid = ply:SteamID()
    local steamid64 = ply:SteamID64()

    if table.HasValue(allowed_grades, usergroup) then return true end
    if table.HasValue(allowed_steamids, steamid) then return true end
    if table.HasValue(allowed_steamids, steamid64) then return true end

    return false
end

local function DrawHitBox(ent, color)
    local obb = ent:OBBMaxs() - ent:OBBMins()
    local center = ent:OBBCenter()
    local obb_center = ent:GetPos() + center

    local corners = {
        Vector(obb.x, -obb.y, -obb.z),
        Vector(-obb.x, -obb.y, -obb.z),
        Vector(-obb.x, obb.y, -obb.z),
        Vector(obb.x, obb.y, -obb.z),
        Vector(obb.x, -obb.y, obb.z),
        Vector(-obb.x, -obb.y, obb.z),
        Vector(-obb.x, obb.y, obb.z),
        Vector(obb.x, obb.y, obb.z)
    }

    local transformed_corners = {}
    for _, corner in ipairs(corners) do
        corner:Rotate(ent:GetAngles())
        corner = corner + obb_center
        local screen_pos = corner:ToScreen()
        table.insert(transformed_corners, screen_pos)
    end

    draw.NoTexture()
    surface.SetDrawColor(color)

    
    for i = 1, 4 do
        surface.DrawLine(transformed_corners[i].x, transformed_corners[i].y, transformed_corners[i + 4].x, transformed_corners[i + 4].y)
        surface.DrawLine(transformed_corners[i].x, transformed_corners[i].y, transformed_corners[i == 4 and 1 or i + 1].x, transformed_corners[i == 4 and 1 or i + 1].y)
        surface.DrawLine(transformed_corners[i + 4].x, transformed_corners[i + 4].y, transformed_corners[i + 5 == 9 and 5 or i + 5].x, transformed_corners[i + 5 == 9 and 5 or i + 5].y)
    end

    return obb_center:ToScreen()
end

local function DrawBones(ent, color)
    if not ent.GetBoneCount then return end

    local boneCount = ent:GetBoneCount()
    if not boneCount then return end

    local bone_positions = {}
    for i = 0, boneCount - 1 do
        local bonePos, boneAng = ent:GetBonePosition(i)
        if bonePos then
            local bonePosScreen = bonePos:ToScreen()
            if bonePosScreen.visible then
                bone_positions[i] = bonePosScreen
            end
        end
    end

    for i = 0, boneCount - 1 do
        local bonePosScreen = bone_positions[i]
        if bonePosScreen then
            local parentBoneIndex = ent:GetBoneParent(i)
            if parentBoneIndex and bone_positions[parentBoneIndex] then
                surface.SetDrawColor(color)
                surface.DrawLine(bonePosScreen.x, bonePosScreen.y, bone_positions[parentBoneIndex].x, bone_positions[parentBoneIndex].y)
            end
        end
    end
end

local function DrawESP()
    if not esp_enabled then return end

    local eye_pos = LocalPlayer():EyePos()
    local eye_angles = LocalPlayer():EyeAngles()
    local end_pos = eye_pos + eye_angles:Forward() * max_distance_line

    for _, ent_type in ipairs(esp_entities) do
        for _, ent in ipairs(ents.FindByClass(ent_type)) do
            if ent ~= LocalPlayer() then -- Exclure votre propre entité
                local pos = ent:GetPos()
                local pos_screen = pos:ToScreen()
                local distance = eye_pos:Distance(pos)

                if pos_screen.visible then
                    local color = Color(255, 255, 255)
                    local draw_name = true
                    
                    if ent:IsPlayer() then
                        color = Color(0, 255, 0) -- Vert pour les joueurs
                        -- Dessiner la ligne de regard pour les joueurs
                        local forward = ent:EyeAngles():Forward()
                        local end_pos = pos + forward * max_distance_line
                        local end_pos_screen = end_pos:ToScreen()
                        if end_pos_screen.visible then
                            surface.SetDrawColor(color)
                            surface.DrawLine(pos_screen.x, pos_screen.y, end_pos_screen.x, end_pos_screen.y)
                        end
                        
                        -- Afficher le nom, la vie, le bouclier et le grade du joueur
                        local name = ent:Nick()
                        local health = ent:Health()
                        local armor = ent:Armor()
                        local job = ent:getDarkRPVar("job")
                        local grade = ent:GetNWString("usergroup") or "Joueur"
                        draw.DrawText(name .. " (" .. job .. ", " .. grade .. ")\nHealth: " .. health .. "\nArmor: " .. armor, "DermaDefault", pos_screen.x, pos_screen.y, color, TEXT_ALIGN_CENTER)
                        
                        -- Ne pas dessiner le nom si le joueur est trop éloigné
                        if distance > max_distance_name then
                            draw_name = false
                        end
                    elseif ent:IsNPC() then
                        color = Color(255, 0, 0) -- Rouge pour les NPCs
                        -- Dessiner la ligne de regard pour les NPCs
                        local forward = ent:GetAngles():Forward()
                        local end_pos = pos + forward * max_distance_line
                        local end_pos_screen = end_pos:ToScreen()
                        if end_pos_screen.visible then
                            surface.SetDrawColor(color)
                            surface.DrawLine(pos_screen.x, pos_screen.y, end_pos_screen.x, end_pos_screen.y)
                        end
                        
                        -- Afficher la vie des NPCs
                        local npc_health = ent:Health()
                        draw.DrawText("NPC\nHealth: " .. npc_health, "DermaDefault", pos_screen.x, pos_screen.y, color, TEXT_ALIGN_CENTER)
                    else
                        color = Color(0, 0, 255) -- Bleu pour les véhicules
                        
                        -- Afficher la vie du véhicule
                        if ent:IsVehicle() then
                            local vehicle_health = ent:GetNWInt("Health")
                            draw.DrawText("Vehicle Health: " .. vehicle_health, "DermaDefault", pos_screen.x, pos_screen.y, color, TEXT_ALIGN_CENTER)
                        end
                    end

                    -- Dessiner une ligne entre le joueur et l'entité
                    if distance <= max_distance_line then
                        surface.SetDrawColor(color)
                        surface.DrawLine(ScrW() / 2, ScrH() / 2, pos_screen.x, pos_screen.y)
                    end

                    -- Dessiner les os
                    DrawBones(ent, color)

                    -- Dessiner le nom si nécessaire
                    if draw_name then
                        local obb_center_screen = DrawHitBox(ent, color)
                        if obb_center_screen then
                            draw.DrawText(name, "DermaDefault", obb_center_screen.x, obb_center_screen.y, color, TEXT_ALIGN_CENTER)
                        end
                    end
                end
            end
        end
    end

    -- Dessiner la ligne indiquant où le joueur regarde
    surface.SetDrawColor(Color(255, 255, 0)) -- Jaune
    surface.DrawLine(ScrW() / 2, ScrH() / 2, end_pos:ToScreen().x, end_pos:ToScreen().y)
end

local function ToggleESP(ply)
    if not IsAllowed(ply) then
        return
    end

    esp_enabled = not esp_enabled
    local message = "ESP " .. (esp_enabled and "activé" or "désactivé")
    chat.AddText(Color(255, 255, 255), message)
    print(message)
end

concommand.Add("esp_toggle", function(ply) ToggleESP(ply) end)

-- Hook pour dessiner l'ESP à chaque frame
hook.Add("HUDPaint", "DrawESP", DrawESP)
