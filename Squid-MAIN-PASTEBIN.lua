-- SQUID • main loader, executor build v2.1
-- This source is compiled together with the separate key gate and dashboard modules.
-- Paste only the generated Squid-MAIN-PASTEBIN.lua into Pastebin.
-- Owner: the license server must be deployed over HTTPS before activation can work.
local API_BASE = [=[https://alien-wax-conclusions-gains.trycloudflare.com]=]
local VERSION = "2.1.0"

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
if not player then warn("Squid: Roblox LocalPlayer unavailable"); return end
local camera = workspace.CurrentCamera
if not camera then repeat task.wait(.1) until workspace.CurrentCamera; camera = workspace.CurrentCamera end

local env = _G
if type(getgenv) == "function" then
    local ok, v = pcall(getgenv)
    if ok and type(v) == "table" then env = v end
end
if type(env.__SQUID_CLOSE) == "function" then pcall(env.__SQUID_CLOSE) end

local requestFn = (syn and syn.request) or (http and http.request) or http_request or request
local filePath = "Squid/session.json"
local state = { install_id = HttpService:GenerateGUID(false):gsub("-", ""):lower(), session_token = nil }
local canSave = type(readfile) == "function" and type(writefile) == "function"
local function jsonDecode(v)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, v)
    return ok and type(data) == "table" and data or nil
end
if canSave then
    local ok, contents = pcall(readfile, filePath)
    local value = ok and jsonDecode(contents) or nil
    if value and type(value.install_id) == "string" and #value.install_id == 32
       and value.install_id:match("^[a-f0-9]+$") then
        state.install_id = value.install_id
        if type(value.session_token) == "string" then state.session_token = value.session_token end
    end
else
    -- Stable fallback for repeat runs without file APIs. This is not proof of account identity.
    state.install_id = ("%032x"):format(player.UserId)
end
local function save()
    if not canSave then return false end
    local ok = pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) == "function" then
                if not isfolder("Squid") then makefolder("Squid") end
            else pcall(makefolder, "Squid") end
        end
        writefile(filePath, HttpService:JSONEncode(state))
    end)
    return ok
end
if canSave and not save() then
    canSave = false
    state.install_id = ("%032x"):format(player.UserId)
    state.session_token = nil
end
local function post(path, body)
    if API_BASE:find("__SQUID_API_BASE__", 1, true) then
        return {valid = false, reason = "api_not_configured"}
    end
    if not API_BASE:match("^https://") then return {valid = false, reason = "https_required"} end
    if type(requestFn) ~= "function" then return {valid = false, reason = "http_missing"} end
    local ok, response = pcall(requestFn, {
        Url = API_BASE:gsub("/$", "") .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or type(response) ~= "table" then return {valid = false, reason = "network"} end
    local status = tonumber(response.StatusCode or response.Status or response.status_code) or 0
    if status == 429 then return {valid = false, reason = "rate_limit"} end
    local result = jsonDecode(response.Body or response.body or "")
    if status < 200 or status >= 300 or not result then return {valid = false, reason = "network"} end
    return result
end
local function activate(key)
    return post("/api/executor/activate", {
        key = tostring(key or ""):gsub("^%s+", ""):gsub("%s+$", ""),
        install_id = state.install_id, place_id = game.PlaceId,
        claimed_roblox_user_id = tostring(player.UserId),
    })
end
local function resume()
    if not state.session_token then return {valid = false, reason = "no_saved_key"} end
    return post("/api/executor/resume", {
        session_token = state.session_token, install_id = state.install_id,
        place_id = game.PlaceId,
    })
end

local parentGui = player:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    local ok, custom = pcall(gethui)
    if ok and typeof(custom) == "Instance" then parentGui = custom end
end
local old = parentGui:FindFirstChild("SQUID_V2")
if old then old:Destroy() end
local screen = Instance.new("ScreenGui")
screen.Name = "SQUID_V2"; screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true; screen.DisplayOrder = 250
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = parentGui

local Theme = {
    bg = Color3.fromRGB(8, 8, 10), surface = Color3.fromRGB(17, 17, 20),
    card = Color3.fromRGB(25, 25, 29), raised = Color3.fromRGB(35, 35, 40),
    line = Color3.fromRGB(63, 63, 68), white = Color3.fromRGB(249, 249, 251),
    muted = Color3.fromRGB(158, 158, 168), dim = Color3.fromRGB(109, 109, 119),
}
local UI = {}
function UI.new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
function UI.round(o, r) UI.new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, o) end
function UI.stroke(o, alpha)
    UI.new("UIStroke", {Color = Theme.line, Transparency = alpha or .35, Thickness = 1}, o)
end
function UI.tween(o, duration, props)
    local t = TweenService:Create(o, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play(); return t
end
function UI.label(parent, value, size, pos, dim, bold, color)
    return UI.new("TextLabel", {
        Position = pos, Size = dim, BackgroundTransparency = 1,
        Text = value, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = size, TextColor3 = color or Theme.white,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end
function UI.button(parent, value, pos, dim, bright)
    local b = UI.new("TextButton", {
        Position = pos, Size = dim, Text = value, Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = bright and Theme.bg or Theme.white,
        BackgroundColor3 = bright and Theme.white or Theme.card,
        AutoButtonColor = false,
    }, parent)
    UI.round(b, 9)
    if not bright then UI.stroke(b, .6) end
    b.MouseEnter:Connect(function()
        UI.tween(b, .18, {BackgroundColor3 = bright and Color3.fromRGB(223,223,230) or Theme.raised})
    end)
    b.MouseLeave:Connect(function()
        UI.tween(b, .18, {BackgroundColor3 = bright and Theme.white or Theme.card})
    end)
    return b
end
function UI.shine(label)
    label.TextStrokeColor3 = Theme.white
    label.TextStrokeTransparency = .87
    local grad = UI.new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 99, 108)),
            ColorSequenceKeypoint.new(.27, Color3.fromRGB(205, 205, 213)),
            ColorSequenceKeypoint.new(.44, Theme.white),
            ColorSequenceKeypoint.new(.55, Color3.fromRGB(136, 136, 145)),
            ColorSequenceKeypoint.new(.78, Theme.white),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(105, 105, 116)),
        }), Offset = Vector2.new(-1,0),
    }, label)
    task.spawn(function()
        while label.Parent and screen.Parent do
            UI.tween(grad, 3.1, {Offset = Vector2.new(1,0)}).Completed:Wait()
            grad.Offset = Vector2.new(-1,0)
            task.wait(1.4)
        end
    end)
end

local ctx = {
    player = player, screen = screen, camera = camera, userInput = UserInputService,
    runService = RunService, lighting = Lighting, debris = Debris, theme = Theme,
    ui = UI, state = state, version = VERSION, canSave = canSave,
    save = save, activate = activate, resume = resume, authorized = false,
    connections = {}, shutdown = false,
}
-- Build step inserts KeyGate and Dashboard as inlined modules here.
local SquidKeyGate = (function()
-- SQUID KEY SYSTEM • separate source module • public-safe, no admin secrets.
-- This is intentionally bundled into the single customer-facing main script.
return function(ctx, authorize)
    local UI, T = ctx.ui, ctx.theme
    local activeUI, busy = nil, false
    local message = {
        api_not_configured = "Owner setup incomplete: connect your license server.",
        https_required = "The license API must use HTTPS.",
        http_missing = "This executor does not support HTTP POST requests.",
        no_saved_key = "Enter your Squid key below.",
        invalid = "Invalid key. Check the code and try again.",
        revoked = "This license was revoked.",
        paused = "This license is currently paused.",
        expired = "This license has expired.",
        seat_limit = "This license has reached its installation limit.",
        wrong_place = "This key doesn't include this game.",
        network = "Can't reach the license server. Try again later.",
        rate_limit = "Too many attempts. Please try again shortly.",
    }
    local function display(reason)
        if activeUI and activeUI.status.Parent then
            activeUI.status.Text = message[reason] or "Enter your key to unlock Squid."
        end
    end
    local function finish(result)
        if activeUI and activeUI.root.Parent then
            local status = activeUI.status
            status.Text = "KEY VERIFIED  /  STARTING SQUID"
            local fill = activeUI.fill
            UI.tween(fill, .75, {Size = UDim2.fromScale(1,1)}).Completed:Wait()
            UI.tween(activeUI.root, .3, {BackgroundTransparency = 1}).Completed:Wait()
            activeUI.root:Destroy()
            activeUI = nil
        end
        authorize(result)
    end
    local function unlock(key)
        if busy or not activeUI then return end
        if #key < 10 then display("invalid"); return end
        busy = true
        activeUI.submit.Text = "VERIFYING LICENSE ..."
        activeUI.status.Text = "Contacting Squid licensing service"
        local result = ctx.activate(key)
        if result.valid and type(result.session_token) == "string" then
            ctx.state.session_token = result.session_token
            ctx.save()
            finish(result)
        else
            display(result.reason)
        end
        if activeUI and activeUI.submit.Parent then activeUI.submit.Text = "UNLOCK SQUID  →" end
        busy = false
    end
    local function show(reason)
        if activeUI and activeUI.root.Parent then
            display(reason or "no_saved_key")
            return
        end
        local root = UI.new("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = T.bg,
            BackgroundTransparency = .24, BorderSizePixel = 0,
        }, ctx.screen)
        local panel = UI.new("Frame", {
            AnchorPoint = Vector2.new(.5,.5), Position = UDim2.fromScale(.5,.5),
            Size = UDim2.fromOffset(420,342), BackgroundColor3 = T.surface,
            BorderSizePixel = 0,
        }, root)
        UI.round(panel, 17); UI.stroke(panel, .18)
        UI.new("UISizeConstraint", {
            MaxSize = Vector2.new(420,342), MinSize = Vector2.new(280,300),
        }, panel)
        local viewport = ctx.camera.ViewportSize
        panel.Size = UDim2.fromOffset(math.min(420, math.max(280, viewport.X - 24)), 342)
        local label = UI.label(panel,"✳  squid",37, UDim2.fromOffset(30,25),UDim2.new(1,-60,0,52),true)
        UI.shine(label)
        UI.label(panel,"PRIVATE ACCESS  /  SQUID V"..ctx.version,10,UDim2.fromOffset(32,84),UDim2.new(1,-64,0,18),true,T.muted)
        UI.label(panel,"Enter your license key once.",13,UDim2.fromOffset(32,119),UDim2.new(1,-64,0,22),false,T.white)
        local field = UI.new("TextBox", {
            Position = UDim2.fromOffset(32,160), Size = UDim2.new(1,-64,0,44),
            BackgroundColor3 = T.card, BorderSizePixel = 0,
            Text = "", PlaceholderText = "SQUID-XXXX-XXXX-XXXX-XXXX",
            TextColor3 = T.white, PlaceholderColor3 = T.dim,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
        },panel)
        UI.round(field,9); UI.stroke(field,.55)
        UI.new("UIPadding", {PaddingLeft=UDim.new(0,13)},field)
        local submit = UI.button(panel,"UNLOCK SQUID  →",UDim2.fromOffset(32,218),UDim2.new(1,-64,0,43),true)
        local status = UI.label(panel,"Checking saved session ...",11,UDim2.fromOffset(32,271),UDim2.new(1,-64,0,36),false,T.muted)
        status.TextWrapped = true
        local track=UI.new("Frame",{Position=UDim2.new(0,32,1,-17),Size=UDim2.new(1,-64,0,3),BackgroundColor3=T.line,BorderSizePixel=0},panel)
        UI.round(track,3)
        local fill=UI.new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=T.white,BorderSizePixel=0},track)
        UI.round(fill,3)
        activeUI = {root=root,field=field,submit=submit,status=status,fill=fill}
        submit.MouseButton1Click:Connect(function() unlock(field.Text) end)
        field.FocusLost:Connect(function(enter) if enter then unlock(field.Text) end end)
        if reason then display(reason); return end
        if not ctx.state.session_token then display("no_saved_key"); return end
        task.spawn(function()
            busy = true
            local result = ctx.resume()
            if not activeUI or not activeUI.root.Parent then busy = false; return end
            if result.valid then
                finish(result)
            else
                display(result.reason)
            end
            busy = false
        end)
    end
    return {show = show}
end

end)()

local SquidDashboard = (function()
-- SQUID DASHBOARD • separate source module, combined into the customer main script at build time.
-- All universal visual functions here are LOCAL / client-side, not server-replicated.
return function(ctx)
    local UI, T = ctx.ui, ctx.theme
    local uiRoot, panel, backdrop, page, footer, inputConn, renderConn
    local logoutHandler, license, currentTab = nil, nil, "Overview"
    local elements, features, nav = {}, {}, {}
    local startFov = ctx.camera.FieldOfView
    local originalClock = ctx.lighting.ClockTime
    local fx = {}
    local cleanup = {}
    local tabs = {"Overview","Universal","Visual Lab","Radar","Games","Settings"}
    if ctx.bronx3 and ctx.bronx3.supported then table.insert(tabs, 5, "THA BRONX 3") end
    local function track(item) table.insert(cleanup, item); return item end
    local function activateOnly(name)
        for key, button in pairs(nav) do
            UI.tween(button, .18, {
                BackgroundColor3 = key == name and T.white or T.card,
                TextColor3 = key == name and T.bg or T.muted,
            })
        end
    end
    local function dispose(item)
        if typeof(item) == "RBXScriptConnection" then item:Disconnect()
        elseif typeof(item) == "Instance" and item.Parent then item:Destroy() end
    end
    local function effect(name)
        if fx[name] and fx[name].Parent then return fx[name] end
        local x = UI.new("ColorCorrectionEffect", {Name="Squid_"..name,Enabled=false},ctx.lighting)
        fx[name] = x
        return x
    end
    local function colorMode(name)
        features.silver = name == "silver"
        features.noir = name == "noir"
        features.icy = name == "icy"
        local silver,noir,icy = effect("Silver"),effect("Noir"),effect("Icy")
        silver.Contrast=.14; silver.Saturation=-.38; silver.Brightness=.02
        silver.TintColor=Color3.fromRGB(237,241,255)
        noir.Contrast=.28; noir.Saturation=-1; noir.Brightness=-.04
        icy.Contrast=.18; icy.Saturation=-.2; icy.Brightness=.015
        icy.TintColor=Color3.fromRGB(175,208,255)
        silver.Enabled=features.silver; noir.Enabled=features.noir; icy.Enabled=features.icy
    end
    local function removeEcho()
        features.echo = false
    end
    local function resetVisuals()
        colorMode("")
        features.bars=false; features.crosshair=false
        features.waypoint=false; features.outlines=false
        features.compass=false; features.fps=false; features.echo=false; features.night=false; features.fov=false
        if elements.topbar then UI.tween(elements.topbar,.25,{Size=UDim2.new(1,0,0,0)}) end
        if elements.bottombar then UI.tween(elements.bottombar,.25,{Size=UDim2.new(1,0,0,0)}) end
        if elements.crosshair then elements.crosshair.Visible=false end
        if elements.compass then elements.compass.Visible=false end
        if elements.telemetry then elements.telemetry.Visible=false end
        if elements.waypoint then elements.waypoint:Destroy();elements.waypoint=nil end
        for _, mark in pairs(elements.highlights or {}) do dispose(mark) end
        elements.highlights = {}
        removeEcho()
        UI.tween(ctx.camera,.3,{FieldOfView=startFov})
        ctx.lighting.ClockTime=originalClock
    end
    local function listClear()
        if not page then return end
        for _, o in ipairs(page:GetChildren()) do
            if not o:IsA("UIListLayout") then o:Destroy() end
        end
        page.CanvasPosition=Vector2.zero
    end
    local function note(s, height)
        local row=UI.new("TextLabel", {
            Size=UDim2.new(1,-8,0,height or 55),Text=s,TextWrapped=true,
            BackgroundTransparency=1,TextColor3=T.muted,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
            Font=Enum.Font.Gotham,
        },page)
        return row
    end
    local function item(title, detail, status, callback, on)
        local row=UI.new("Frame",{Size=UDim2.new(1,-6,0,61),BackgroundColor3=T.card,BorderSizePixel=0},page)
        UI.round(row,10); UI.stroke(row,.66)
        local label=UI.label(row,title,13,UDim2.fromOffset(13,9),UDim2.new(1,-127,0,22),true)
        label.TextTruncate=Enum.TextTruncate.AtEnd
        local sub=UI.label(row,detail,10,UDim2.fromOffset(13,33),UDim2.new(1,-127,0,20),false,T.muted)
        sub.TextTruncate=Enum.TextTruncate.AtEnd
        local b=UI.button(row,on and "ON" or (status or "OPEN"),UDim2.new(1,-105,0,17),UDim2.fromOffset(91,29),false)
        if callback then
            b.MouseButton1Click:Connect(callback)
        else
            b.Active=false;b.TextColor3=T.muted
        end
        return row
    end
    local function nearestPlayers(limit)
        local result={}
        local ch=ctx.player.Character
        local center=ch and ch:FindFirstChild("HumanoidRootPart")
        if not center then return result end
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr ~= ctx.player then
                local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    table.insert(result,{player=plr,root=root,dist=(root.Position-center.Position).Magnitude})
                end
            end
        end
        table.sort(result,function(a,b) return a.dist < b.dist end)
        while #result > limit do table.remove(result) end
        return result
    end
    local function redrawOutlines()
        local existing=elements.highlights or {}
        for _, highlight in pairs(existing) do dispose(highlight) end
        elements.highlights = {}
        if not features.outlines then return end
        for _, p in ipairs(nearestPlayers(16)) do
            if p.dist < 110 and p.player.Character then
                local h=UI.new("Highlight", {
                    Name="SquidNearbyOutline",Adornee=p.player.Character,
                    DepthMode=Enum.HighlightDepthMode.Occluded,
                    FillColor=T.white,FillTransparency=.93,
                    OutlineColor=T.white,OutlineTransparency=.12,
                },workspace.CurrentCamera)
                table.insert(elements.highlights,h)
            end
        end
    end
    local function echoLoop()
        task.spawn(function()
            while features.echo and ctx.authorized and ctx.screen.Parent do
                local root=ctx.player.Character and ctx.player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local p=UI.new("Part",{
                        Name="SquidLocalEcho",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
                        Shape=Enum.PartType.Ball,Material=Enum.Material.Neon,
                        Color=T.white,Transparency=.73,Size=Vector3.new(.28,.28,.28),
                        CFrame=CFrame.new(root.Position - Vector3.new(0,2,0)),
                    },workspace)
                    UI.tween(p,.85,{Transparency=1,Size=Vector3.new(.04,.04,.04)})
                    ctx.debris:AddItem(p,1)
                end
                task.wait(.16)
            end
        end)
    end
    local function setWaypoint(on)
        features.waypoint=on
        if elements.waypoint then elements.waypoint:Destroy();elements.waypoint=nil end
        if not on then return end
        local root=ctx.player.Character and ctx.player.Character:FindFirstChild("HumanoidRootPart")
        if not root then features.waypoint=false; return end
        local base=UI.new("Part",{
            Name="SquidWaypointLocal",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
            Transparency=1,Size=Vector3.new(1,1,1),Position=root.Position,
        },workspace)
        local gui=UI.new("BillboardGui",{
            Size=UDim2.fromOffset(115,46),StudsOffset=Vector3.new(0,5,0),AlwaysOnTop=true,
        },base)
        local marker=UI.label(gui,"◇  WAYPOINT",12,UDim2.fromScale(0,0),UDim2.fromScale(1,1),true)
        marker.TextXAlignment=Enum.TextXAlignment.Center
        UI.shine(marker)
        elements.waypoint=base
    end
    local function toggleFeature(key)
        features[key]=not features[key]
        if key == "silver" or key == "noir" or key == "icy" then
            colorMode(features[key] and key or "")
        elseif key == "bars" then
            local n=features.bars and 36 or 0
            UI.tween(elements.topbar,.35,{Size=UDim2.new(1,0,0,n)})
            UI.tween(elements.bottombar,.35,{Size=UDim2.new(1,0,0,n)})
        elseif key == "crosshair" then
            elements.crosshair.Visible=features.crosshair
        elseif key == "compass" then
            elements.compass.Visible=features.compass
        elseif key == "fps" then
            elements.telemetry.Visible=features.fps
        elseif key == "echo" and features.echo then echoLoop()
        elseif key == "outlines" then redrawOutlines()
        elseif key == "waypoint" then setWaypoint(features.waypoint)
        end
    end
    local function moduleEnabled(name)
        if not license or type(license.modules)~="table" then return false end
        for _, v in ipairs(license.modules) do if v == name then return true end end
        return false
    end
    local showTab
    showTab=function(name)
        if not page then return end
        currentTab=name
        activateOnly(name)
        elements.breadcrumb.Text="SQUID / "..string.upper(name)
        elements.title.Text=name
        listClear()
        if name=="Overview" then
            elements.subtitle.Text="Built for a clean, fast experience."
            note("SQUID V"..ctx.version.."   /   KEY VERIFIED\nWelcome, "..ctx.player.DisplayName..".",54)
            item("Universal toolkit","Personal creative and HUD utilities","EXPLORE",function() showTab("Universal") end)
            item("Visual lab","Cinematic presets and custom effects","EXPLORE",function() showTab("Visual Lab") end)
            item("Signal radar","Nearby player distances; local overlay","OPEN",function() showTab("Radar") end)
            item("Game library","Modules and supported experiences","OPEN",function() showTab("Games") end)
            if ctx.bronx3 and ctx.bronx3.supported then
                item("THA BRONX 3","Experimental job and dropped-loot automation","OPEN",function() showTab("THA BRONX 3") end)
            end
        elseif name=="Universal" then
            elements.subtitle.Text="Local tools that work across compatible experiences."
            if not moduleEnabled("universal") then note("This license doesn't include Universal.",75);return end
            item("FOV boost","Switch between your regular view and 95°",nil,function()
                features.fov=not features.fov
                UI.tween(ctx.camera,.4,{FieldOfView=features.fov and 95 or startFov})
                showTab(name)
            end,features.fov)
            item("Center reticle","Minimal monochrome aiming overlay",nil,function() toggleFeature("crosshair");showTab(name) end,features.crosshair)
            item("Motion echo","Animated local footstep signal",nil,function() toggleFeature("echo");showTab(name) end,features.echo)
            item("Compass heading","Live cardinal heading on-screen",nil,function() toggleFeature("compass");showTab(name) end,features.compass)
            item("Performance telemetry","FPS, movement speed and nearby count",nil,function() toggleFeature("fps");showTab(name) end,features.fps)
            item("Local waypoint","Pin your present location in the world",nil,function() toggleFeature("waypoint");showTab(name) end,features.waypoint)
            note("These tools don't replicate to other players. The waypoint and echo are client-local.",46)
        elseif name=="Visual Lab" then
            elements.subtitle.Text="Your custom cinematography controls."
            if not moduleEnabled("universal") then note("Requires the Universal module.",60);return end
            item("Silver film","Desaturated silver-blue color grading",nil,function() toggleFeature("silver");showTab(name) end,features.silver)
            item("Noir","Black and white with deep contrast",nil,function() toggleFeature("noir");showTab(name) end,features.noir)
            item("Icy atmosphere","Cool highlights and a crisp image",nil,function() toggleFeature("icy");showTab(name) end,features.icy)
            item("Cinema bars","Animated widescreen frame",nil,function() toggleFeature("bars");showTab(name) end,features.bars)
            item("Night mode","Personal night-time lighting",nil,function()
                features.night=not features.night
                ctx.lighting.ClockTime=features.night and 0 or originalClock
                showTab(name)
            end,features.night)
            item("Reset appearance","Restore all local camera and visual changes","RESET",function()
                resetVisuals(); showTab(name)
            end)
        elseif name=="Radar" then
            elements.subtitle.Text="Live player proximity, calculated on your device."
            if not moduleEnabled("universal") then note("Requires the Universal module.",60);return end
            item("Nearby outlines","Subtle, visible-only player outlines",nil,function()
                toggleFeature("outlines");showTab(name)
            end,features.outlines)
            local nearby=nearestPlayers(10)
            if #nearby == 0 then note("Nobody nearby, or your character hasn't loaded.",65) end
            for _, info in ipairs(nearby) do
                item(info.player.DisplayName,"@"..info.player.Name.."  •  "..math.floor(info.dist+0.5).." studs","NEAR")
            end
            item("Refresh distances","Update the nearby player list","SCAN",function() showTab(name) end)
            note("Distances and outlines are only shown to you. No hidden server data is accessed.",42)
        elseif name=="Games" then
            elements.subtitle.Text="Place-aware modules; no untested game claims."
            item("Current place",tostring(game.PlaceId),"INFO")
            item("Universal","Client-side visual and diagnostics toolkit","READY",function() showTab("Universal") end)
            if ctx.bronx3 and ctx.bronx3.supported then
                item("THA BRONX 3","Construction, nearby cash and dropped gun pickup (experimental)","OPEN",function() showTab("THA BRONX 3") end)
            else
                item("THA BRONX 3","Only available in game Place ID 128899661081075","OTHER GAME")
            end
            note("Game-specific automation is experimental until verified in a live server. Client scripts cannot guarantee FE or change server-owned inventories.",72)
        elseif name=="THA BRONX 3" then
            elements.subtitle.Text="Experimental • job assistance and dropped-loot collection"
            local b=ctx.bronx3
            if not b or not b.supported then
                note("This page is only available inside THA BRONX 3.",65)
                return
            end
            if not moduleEnabled("tha-bronx-3") then
                note("This license does not include the THA BRONX 3 module. The owner can add tha-bronx-3 to this key's modules.",90)
                return
            end
            local progress,stats = b.state()
            note("EXPERIMENTAL / NOT LIVE VERIFIED\n"..progress,58)
            item("Construction AutoFarm","Start job, take plywood, attempt wall placement",nil,function()
                b.toggle("construction");showTab(name)
            end,b.isOn("construction"))
            item("Nearby cash pickup","Search for eligible dropped cash and loot bags within 90 studs",nil,function()
                b.toggle("cash");showTab(name)
            end,b.isOn("cash"))
            item("Dropped gun pickup","Try pickup prompts for abandoned weapons (not equipped guns)",nil,function()
                b.toggle("guns");showTab(name)
            end,b.isOn("guns"))
            item("Movement mode","Currently "..b.movementMode().." • WALK uses navigation, FAST may be corrected","SWITCH",function()
                b.movement();showTab(name)
            end)
            item("Live game scan","Check for construction prompts, eligible loot and executor support","SCAN",function()
                local v=b.scan()
                elements.lastScan = string.format("Job start: %s | Wood: %s | Wall: %s\nNearby/drop candidates: %d guns, %d cash\nExecutor prompt support: %s | Wallet: %s",
                    tostring(v.start),tostring(v.grab),tostring(v.wall),v.guns,v.cash,tostring(v.fireprompt),v.money and ("$"..tostring(v.money)) or "not exposed")
                showTab(name)
            end)
            if elements.lastScan then note(elements.lastScan,65) end
            item("Session activity",("Block attempts: %d | Cash prompts: %d | Gun prompts: %d"):format(
                stats.blocks,stats.cashPickups,stats.gunPickups),"COUNTS")
            note("Counts record interaction attempts, NOT guaranteed payouts or successful acquisitions. No direct player inventory stealing, item duplication, server currency edits, or guaranteed FE.",79)
        elseif name=="Settings" then
            elements.subtitle.Text="Your license and interface preferences."
            item("Plan",tostring(license and license.plan or "Squid Standard"),"ACTIVE")
            item("Expiry",tostring(license and license.expires_at or "No expiration"),"INFO")
            item("Installation",ctx.state.install_id:sub(1,8).."...","INFO")
            item("Saved sign-in",ctx.canSave and "Session saved by executor file APIs" or "Storage unavailable; key needed each time","INFO")
            item("Close panel","Right Shift to show or hide","HIDE",function() backdrop.Visible=false end)
            item("Reset everything","Disable local effects and restore camera","RESET",function()
                resetVisuals();showTab(name)
            end)
            item("Sign out","Forget this installation's saved session","LOG OUT",function()
                if logoutHandler then logoutHandler() end
            end)
            note("Key checks are handled by your HTTPS license API, not by a hard-coded secret in the script.",60)
        end
    end
    local function buildOverlay()
        local top = UI.new("Frame",{Name="SquidTopFilm",Size=UDim2.new(1,0,0,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=40},ctx.screen)
        local bottom = UI.new("Frame",{Name="SquidBottomFilm",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=40},ctx.screen)
        elements.topbar=top;elements.bottombar=bottom
        local cross=UI.new("Frame",{Name="SquidCrosshair",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=T.white,BorderSizePixel=0,Visible=false,ZIndex=43},ctx.screen)
        UI.round(cross,2);elements.crosshair=cross
        local compass=UI.label(ctx.screen,"N  •  000°",12,UDim2.fromScale(.42,.07),UDim2.fromScale(.16,.05),true)
        compass.TextXAlignment=Enum.TextXAlignment.Center; compass.Visible=false;compass.ZIndex=45
        elements.compass=compass
        local tel=UI.label(ctx.screen,"FPS  --   /   SPEED  --",11,UDim2.fromScale(.02,.89),UDim2.fromScale(.43,.06),true)
        tel.Visible=false; tel.ZIndex=45;elements.telemetry=tel
    end
    local function liveTick(dt)
        if not uiRoot or not uiRoot.Parent then return end
        elements.frameCount=(elements.frameCount or 0)+1
        elements.frameTime=(elements.frameTime or 0)+dt
        if elements.frameTime>=1 then
            elements.lastFps=math.floor(elements.frameCount/elements.frameTime+.5)
            elements.frameCount=0;elements.frameTime=0
        end
        if elements.compass and features.compass then
            local look=ctx.camera.CFrame.LookVector
            local heading=(math.deg(math.atan2(-look.X,-look.Z)) + 360)%360
            local points={"N","NE","E","SE","S","SW","W","NW"}
            local idx=math.floor((heading+22.5)/45)%8+1
            elements.compass.Text=string.format("%s    /    %03d°",points[idx],math.floor(heading+.5))
        end
        if elements.telemetry and features.fps then
            local root=ctx.player.Character and ctx.player.Character:FindFirstChild("HumanoidRootPart")
            local speed=root and root.AssemblyLinearVelocity.Magnitude or 0
            elements.telemetry.Text=string.format("FPS  %d     •     SPEED  %d STUDS/S",elements.lastFps or 0,math.floor(speed+.5))
        end
    end
    local function open(data)
        if uiRoot then resetVisuals();uiRoot:Destroy();uiRoot=nil end
        license=data
        features = {}; elements={highlights={}}
        ctx.authorized=true
        backdrop=UI.new("Frame",{Name="SquidOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=T.bg,BackgroundTransparency=.28,BorderSizePixel=0},ctx.screen)
        uiRoot=backdrop
        panel=UI.new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(720,490),BackgroundColor3=T.surface,BorderSizePixel=0,ClipsDescendants=true},backdrop)
        UI.round(panel,16);UI.stroke(panel,.15)
        local header=UI.new("Frame",{Size=UDim2.new(1,0,0,62),BackgroundColor3=T.surface,BorderSizePixel=0},panel)
        UI.label(header,"✳",26,UDim2.fromOffset(19,10),UDim2.fromOffset(35,39),true)
        local logo=UI.label(header,"squid",26,UDim2.fromOffset(54,13),UDim2.fromOffset(114,34),true)
        UI.shine(logo)
        UI.label(header,"EXECUTOR EDITION   /   V"..ctx.version,10,UDim2.fromOffset(183,18),UDim2.new(1,-270,0,26),true,T.dim)
        local minimize=UI.button(header,"—",UDim2.new(1,-83,0,16),UDim2.fromOffset(31,28),false)
        minimize.MouseButton1Click:Connect(function() backdrop.Visible=false end)
        local x=UI.button(header,"×",UDim2.new(1,-45,0,16),UDim2.fromOffset(30,28),false)
        x.TextSize=19;x.MouseButton1Click:Connect(function() backdrop.Visible=false end)
        UI.new("Frame",{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundColor3=T.line,BorderSizePixel=0},header)
        local sidebar=UI.new("Frame",{Position=UDim2.fromOffset(0,62),Size=UDim2.new(0,177,1,-85),BackgroundColor3=Color3.fromRGB(21,21,24),BorderSizePixel=0},panel)
        UI.new("Frame",{Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=T.line,BorderSizePixel=0},sidebar)
        local sidebarItems=UI.new("Frame",{Position=UDim2.fromOffset(12,15),Size=UDim2.new(1,-24,1,-30),BackgroundTransparency=1},sidebar)
        UI.new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},sidebarItems)
        nav={}
        local iconFor={Overview="◈",Universal="⌘",["Visual Lab"]="◐",Radar="◎",Games="▦",["THA BRONX 3"]="◇",Settings="⚙"}
        for i,name in ipairs(tabs) do
            local b=UI.button(sidebarItems,(iconFor[name] or "◇").."   "..name,UDim2.fromScale(0,0),UDim2.new(1,0,0,40),false)
            b.LayoutOrder=i;b.TextXAlignment=Enum.TextXAlignment.Left;b.TextColor3=T.muted
            UI.new("UIPadding",{PaddingLeft=UDim.new(0,13)},b)
            b.MouseButton1Click:Connect(function() showTab(name) end)
            nav[name]=b
        end
        local content=UI.new("Frame",{Position=UDim2.fromOffset(177,62),Size=UDim2.new(1,-177,1,-85),BackgroundTransparency=1},panel)
        elements.breadcrumb=UI.label(content,"SQUID / OVERVIEW",10,UDim2.fromOffset(22,9),UDim2.new(1,-44,0,25),true,T.muted)
        elements.title=UI.label(content,"Overview",24,UDim2.fromOffset(22,39),UDim2.new(1,-44,0,38),true)
        elements.subtitle=UI.label(content,"",11,UDim2.fromOffset(22,77),UDim2.new(1,-44,0,23),false,T.muted)
        page=UI.new("ScrollingFrame",{Position=UDim2.fromOffset(22,113),Size=UDim2.new(1,-44,1,-120),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.dim,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},content)
        UI.new("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},page)
        footer=UI.new("Frame",{Position=UDim2.new(0,0,1,-23),Size=UDim2.new(1,0,0,23),BackgroundColor3=Color3.fromRGB(23,23,26),BorderSizePixel=0},panel)
        elements.footStatus=UI.label(footer,"●  LICENSE ACTIVE",9,UDim2.fromOffset(14,0),UDim2.new(1,-30,1,0),true,T.muted)
        local function fit()
            if not panel or not panel.Parent then return end
            local vs=ctx.camera.ViewportSize
            panel.Size=UDim2.fromOffset(math.min(720,math.max(320,vs.X-22)),math.min(490,math.max(320,vs.Y-32)))
        end
        fit()
        track(ctx.camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
        local drag=false;local dragStart;local originalPos
        track(header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                drag=true;dragStart=input.Position;originalPos=panel.Position
                track(input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then drag=false end
                end))
            end
        end))
        track(ctx.userInput.InputChanged:Connect(function(input)
            if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta=input.Position-dragStart
                panel.Position=UDim2.new(originalPos.X.Scale,originalPos.X.Offset+delta.X,originalPos.Y.Scale,originalPos.Y.Offset+delta.Y)
            end
        end))
        buildOverlay()
        renderConn=track(ctx.runService.RenderStepped:Connect(liveTick))
        task.spawn(function()
            while uiRoot and uiRoot.Parent and ctx.authorized do
                if features.outlines then redrawOutlines() end
                task.wait(3)
            end
        end)
        showTab("Overview")
        local loader=UI.new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=T.bg,BorderSizePixel=0,ZIndex=90},panel)
        local logo2=UI.label(loader,"squid",51,UDim2.fromScale(.18,.32),UDim2.fromScale(.64,.16),true)
        logo2.TextXAlignment=Enum.TextXAlignment.Center;logo2.ZIndex=91;UI.shine(logo2)
        local status=UI.label(loader,"LOADING YOUR WORKSPACE",10,UDim2.fromScale(.24,.57),UDim2.fromScale(.52,.08),true,T.muted)
        status.TextXAlignment=Enum.TextXAlignment.Center;status.ZIndex=91
        local rail=UI.new("Frame",{Position=UDim2.fromScale(.29,.69),Size=UDim2.fromScale(.42,.009),BackgroundColor3=T.line,BorderSizePixel=0,ZIndex=91},loader)
        UI.round(rail,6)
        local fill=UI.new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=T.white,BorderSizePixel=0,ZIndex=92},rail)
        UI.round(fill,6)
        UI.tween(fill,1.2,{Size=UDim2.fromScale(1,1)}).Completed:Wait()
        if loader.Parent then loader:Destroy() end
    end
    local function close()
        resetVisuals()
        for _, connection in ipairs(cleanup) do pcall(dispose, connection) end
        cleanup={}
        for _, colorEffect in pairs(fx) do dispose(colorEffect) end
        fx={}
        if uiRoot and uiRoot.Parent then uiRoot:Destroy() end
        uiRoot=nil;panel=nil;backdrop=nil;page=nil;nav={};license=nil
        for _, element in ipairs({"topbar","bottombar","crosshair","compass","telemetry"}) do
            if elements[element] then dispose(elements[element]) end
        end
        elements={}
    end
    return {
        open=open, close=close,
        toggle=function() if backdrop and backdrop.Parent then backdrop.Visible=not backdrop.Visible end end,
        onLogout=function(cb) logoutHandler=cb end,
        updateLicense=function(data) license=data end,
        setConnectionStatus=function(s)
            if elements.footStatus and elements.footStatus.Parent then elements.footStatus.Text="●  "..s end
        end,
    }
end

end)()

local SquidBronx3 = (function()
-- SQUID / THA BRONX 3 • research-based executor module (EXPERIMENTAL)
-- Based on public descriptions of game mechanics; NOT live-tested in the target experience.
-- Only uses replicated prompts and ordinary pickup/job interactions. No remote forgery,
-- server-side inventory edits, currency creation, or other-player inventory seizure.
return function(ctx)
    local PLACE = 128899661081075
    local supported = game.PlaceId == PLACE
    local Workspace = game:GetService("Workspace")
    local PathfindingService = game:GetService("PathfindingService")
    local player = ctx.player
    local operations = {construction=false, cash=false, guns=false}
    local workers = {construction=false, cash=false, guns=false}
    local metrics = {blocks=0, cashPickups=0, gunPickups=0, scans=0, errors=0}
    local statusText = supported and "READY TO SCAN (UNVERIFIED GAME VERSION)" or "ONLY AVAILABLE IN THA BRONX 3"
    local travelMode = "WALK" -- switchable; FAST CFrame movement may be reverted by server
    local destroyed = false
    local lastMoney = nil
    local function alive()
        local character = player.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not root then return nil end
        return character, hum, root
    end
    local function report(message)
        statusText = message
    end
    local function isRunning(kind)
        return supported and ctx.authorized and not ctx.shutdown and not destroyed and operations[kind]
    end
    local function posOf(prompt)
        if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then return nil end
        local origin = prompt.Parent
        if origin:IsA("Attachment") then return origin.WorldPosition end
        if origin:IsA("BasePart") then return origin.Position end
        if origin:IsA("Model") then return origin:GetPivot().Position end
        local ancestor = origin:FindFirstAncestorOfClass("Model")
        if ancestor then return ancestor:GetPivot().Position end
        return nil
    end
    local function distanceTo(prompt)
        local _, _, root = alive()
        local position = posOf(prompt)
        if not root or not position then return math.huge end
        return (root.Position-position).Magnitude
    end
    local function walkTo(position, shouldContinue)
        local _, hum, root = alive()
        if not hum or not root then return false, "character not ready" end
        local distance = (root.Position-position).Magnitude
        if distance < 6 then return true end
        if travelMode == "FAST" then
            -- User-selected instant movement, subject to server correction/anticheat.
            local cf = CFrame.new(position + Vector3.new(0,3,0))
            local ok = pcall(function() root.CFrame = cf end)
            task.wait(.25)
            return ok and (root.Position-position).Magnitude < 14, "server may have rejected quick movement"
        end
        local path = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=8})
        local ok = pcall(function() path:ComputeAsync(root.Position, position) end)
        local waypoints = (ok and path.Status==Enum.PathStatus.Success) and path:GetWaypoints() or nil
        if not waypoints or #waypoints == 0 then
            waypoints = {{Position=position,Action=Enum.PathWaypointAction.Walk}}
        end
        local deadline = os.clock() + math.max(18, math.min(65, distance/7+12))
        for _, waypoint in ipairs(waypoints) do
            if not shouldContinue() then hum:MoveTo(root.Position); return false,"stopped" end
            if os.clock()>deadline then return false,"walking timed out" end
            if waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
            hum:MoveTo(waypoint.Position)
            local stepEnd = os.clock()+math.max(4, math.min(12, (root.Position-waypoint.Position).Magnitude/7+3))
            repeat
                if not shouldContinue() then hum:MoveTo(root.Position); return false,"stopped" end
                if (root.Position-waypoint.Position).Magnitude <= 5 then break end
                if hum.Health <= 0 then return false,"character died" end
                task.wait(.15)
            until os.clock()>stepEnd or os.clock()>deadline
        end
        return (root.Position-position).Magnitude <= 15, "could not reach prompt"
    end
    local function interact(prompt, kind)
        if not isRunning(kind) then return false,"stopped" end
        if not prompt or not prompt.Parent or not prompt.Enabled then return false,"prompt disabled" end
        local target = posOf(prompt)
        if not target then return false,"unknown prompt position" end
        local ok, reason = walkTo(target, function() return isRunning(kind) end)
        if not ok then return false,reason end
        if not isRunning(kind) then return false,"stopped" end
        if type(fireproximityprompt) ~= "function" then
            return false,"executor requires fireproximityprompt()"
        end
        local didFire = pcall(function() fireproximityprompt(prompt) end)
        task.wait(.36)
        return didFire, didFire and "interaction attempted" or "prompt call failed"
    end
    local function getPrompts(parent)
        local prompts = {}
        if parent then
            for _, entry in ipairs(parent:GetDescendants()) do
                if entry:IsA("ProximityPrompt") and entry.Enabled then
                    table.insert(prompts, entry)
                end
            end
        end
        return prompts
    end
    local function choosePrompt(where, words)
        local best,bestDist
        for _, p in ipairs(getPrompts(where)) do
            local desc = ((p.Name or "") .. " " .. (p.ActionText or "") .. " " ..
                (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            local matched = false
            for _, term in ipairs(words) do
                if desc:find(term,1,true) then matched=true;break end
            end
            if matched then
                local d=distanceTo(p)
                if not bestDist or d<bestDist then best,bestDist=p,d end
            end
        end
        return best
    end
    local function hasPlywood()
        local char = player.Character
        local pack = player:FindFirstChildOfClass("Backpack")
        return (pack and pack:FindFirstChild("PlyWood")) or (char and char:FindFirstChild("PlyWood"))
    end
    local function equipPlywood()
        local char, hum = alive()
        if not char then return false end
        if char:FindFirstChild("PlyWood") then return true end
        local pack = player:FindFirstChildOfClass("Backpack")
        local tool = pack and pack:FindFirstChild("PlyWood")
        if tool and tool:IsA("Tool") then
            pcall(function() hum:EquipTool(tool) end)
            task.wait(.2)
            return char:FindFirstChild("PlyWood") ~= nil
        end
        return false
    end
    local function constructionPrompts()
        local area=Workspace:FindFirstChild("ConstructionStuff")
        if not area then return nil,nil,nil end
        local start = area:FindFirstChild("Start Job")
        local grab = area:FindFirstChild("Grab Wood")
        local startPrompt = start and (start:FindFirstChild("Prompt") or start:FindFirstChildWhichIsA("ProximityPrompt",true))
        local grabPrompt = grab and (grab:FindFirstChild("Prompt") or grab:FindFirstChildWhichIsA("ProximityPrompt",true))
        startPrompt = startPrompt or choosePrompt(area,{"start job","start work","clock in"})
        grabPrompt = grabPrompt or choosePrompt(area,{"grab wood","wood","plywood","material"})
        local wallPrompt=nil
        -- The public example describes build sites as Workspace children named Wall.
        -- Prefer enabled prompts directly beneath Wall objects, not arbitrary prompts.
        local bestDist=math.huge
        for _, inst in ipairs(Workspace:GetChildren()) do
            if inst.Name:lower():find("wall",1,true) then
                for _, prompt in ipairs(getPrompts(inst)) do
                    local dist=distanceTo(prompt)
                    if dist<bestDist then wallPrompt,bestDist=prompt,dist end
                end
            end
        end
        if not wallPrompt then wallPrompt=choosePrompt(area,{"place wood","place block","build wall"}) end
        return startPrompt,grabPrompt,wallPrompt
    end
    local function readCash()
        -- Publicly referenced HUD data. Never modify it; server controls earnings.
        local stored=player:FindFirstChild("Stored")
        local value=stored and stored:FindFirstChild("Mooney")
        if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
            return tonumber(value.Value)
        end
        return nil
    end
    local function farmConstruction()
        local failures=0
        local startingCash=readCash()
        report("CONSTRUCTION: LOCATING JOB")
        while isRunning("construction") do
            local char = alive()
            if not char then
                task.wait(1)
            else
                local start,grab,wall=constructionPrompts()
                if not start or not grab then
                    failures=failures+1
                    report("CONSTRUCTION: JOB PROMPTS NOT FOUND")
                    task.wait(2)
                else
                    if player:GetAttribute("WorkingJob") ~= true and not hasPlywood() then
                        local ok,reason=interact(start,"construction")
                        if not ok then failures=failures+1;report("START JOB: "..reason) end
                    end
                    if isRunning("construction") and not hasPlywood() then
                        report("CONSTRUCTION: COLLECTING PLYWOOD")
                        local ok,reason=interact(grab,"construction")
                        if not ok then failures=failures+1; report("GET WOOD: "..reason) end
                        for _=1,8 do
                            if not isRunning("construction") or hasPlywood() then break end
                            task.wait(.25)
                        end
                    end
                    if isRunning("construction") and hasPlywood() then
                        equipPlywood()
                        local _,_,nextWall = constructionPrompts()
                        wall = nextWall
                        if wall then
                            report("CONSTRUCTION: PLACING WOOD")
                            local ok,reason=interact(wall,"construction")
                            if ok then
                                failures=0
                                -- This is an interaction attempt count, NOT a verified paid block.
                                metrics.blocks=metrics.blocks+1
                                report("CONSTRUCTION: PLACEMENT ATTEMPTS "..metrics.blocks)
                            else
                                failures=failures+1;report("PLACE WOOD: "..reason)
                            end
                        else
                            failures=failures+1;report("CONSTRUCTION: NO ACTIVE WALL")
                        end
                    elseif isRunning("construction") then
                        failures=failures+1
                        report("CONSTRUCTION: PLYWOOD NOT RECEIVED")
                    end
                end
                if failures >= 5 then
                    operations.construction=false
                    metrics.errors=metrics.errors+1
                    report("AUTO-STOP: TOO MANY FAILED STEPS; INSPECT GAME UPDATE")
                    break
                end
                task.wait(.5)
            end
        end
        local ending=readCash()
        if startingCash and ending and ending>startingCash then
            report("CONSTRUCTION STOPPED • VERIFIED WALLET CHANGE +$" .. tostring(ending-startingCash))
        end
    end
    local function nameTrail(inst)
        local names={}
        local node=inst
        for _=1,7 do
            if not node or node==Workspace then break end
            table.insert(names,(node.Name or ""):lower())
            node=node.Parent
        end
        return table.concat(names," ")
    end
    local function inOtherPlayerCharacter(inst)
        local node=inst
        while node and node~=Workspace do
            if node:IsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(node) then return true end
            node=node.Parent
        end
        return false
    end
    local function classifyPrompt(prompt)
        if not prompt.Enabled or inOtherPlayerCharacter(prompt) then return nil end
        local context=nameTrail(prompt)
        local action=((prompt.ActionText or "").." "..(prompt.ObjectText or "")):lower()
        if context:match("gunshop") or context:match("gunstop") or context:match("checkout")
            or context:match("store") or context:match("dealer") or context:match("shop")
            or context:match("exotic") or context:match("market") then return nil end
        local isDrop=context:find("drop",1,true) or context:find("loot",1,true)
            or context:find("pickups",1,true) or context:find("dollas",1,true)
        local pickup=action:find("take",1,true) or action:find("pick",1,true)
            or action:find("grab",1,true) or action:find("loot",1,true)
        if not pickup and not isDrop then return nil end
        local guns={"gun","glock","drac","pistol","rifle","ak47","ar15","arp","uzi",
                    "m16","mac10","hellpup","shotgun","smg","revolver","weapon","firearm"}
        local gun=false
        for _,word in ipairs(guns) do
            if context:find(word,1,true) or action:find(word,1,true) then gun=true;break end
        end
        if gun and (isDrop or pickup) then return "guns" end
        local cash=context:find("dollas",1,true) or context:find("cash",1,true)
            or context:find("money",1,true) or context:find("bag",1,true)
            or action:find("cash",1,true)
        if cash and (isDrop or pickup) then return "cash" end
        return nil
    end
    local function findNearestPickup(kind)
        local _, _, root=alive()
        if not root then return nil end
        local best, bestDist=nil, 90 -- only nearby loot: don't chase arbitrary world prompts
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("ProximityPrompt") and classifyPrompt(inst)==kind then
                local distance=distanceTo(inst)
                if distance<bestDist then best,bestDist=inst,distance end
            end
        end
        return best
    end
    local function collectLoop(kind)
        report(kind=="guns" and "DROPPED GUN SCANNER ACTIVE" or "CASH DROP SCANNER ACTIVE")
        local failures=0
        local seen={}
        while isRunning(kind) do
            local prompt=findNearestPickup(kind)
            metrics.scans=metrics.scans+1
            if prompt and (not seen[prompt] or os.clock()-seen[prompt]>8) then
                seen[prompt]=os.clock()
                local ok,reason=interact(prompt,kind)
                if ok then
                    if kind=="guns" then metrics.gunPickups=metrics.gunPickups+1
                    else metrics.cashPickups=metrics.cashPickups+1 end
                    failures=0
                    report((kind=="guns" and "GUN" or "CASH").." PICKUP ATTEMPTED")
                else
                    failures=failures+1
                    report("PICKUP: "..reason)
                    if failures>=5 then
                        operations[kind]=false
                        metrics.errors=metrics.errors+1
                        report("AUTO-STOP: PICKUP FAILED FIVE TIMES")
                        break
                    end
                end
            elseif not prompt then
                report(kind=="guns" and "WATCHING FOR DROPPED GUNS (90 STUDS)" or "WATCHING FOR CASH DROPS (90 STUDS)")
            end
            task.wait(2.6)
        end
    end
    local function toggle(kind)
        if not supported then return false,"Wrong game" end
        if kind~="construction" and kind~="cash" and kind~="guns" then return false,"Unknown operation" end
        operations[kind]=not operations[kind]
        if operations[kind] then
            if not workers[kind] then
                workers[kind]=true
                task.spawn(function()
                    local ok,err=pcall(function()
                        if kind=="construction" then farmConstruction() else collectLoop(kind) end
                    end)
                    if not ok then
                        metrics.errors=metrics.errors+1
                        report("AUTO-STOP: "..tostring(err):sub(1,85))
                    end
                    operations[kind]=false
                    workers[kind]=false
                end)
            end
        else
            report(string.upper(kind).." STOPPED")
        end
        return operations[kind],statusText
    end
    local function scan()
        local start,grab,wall=constructionPrompts()
        local guns,cash=0,0
        for _,entry in ipairs(Workspace:GetDescendants()) do
            if entry:IsA("ProximityPrompt") then
                local kind=classifyPrompt(entry)
                if kind=="guns" then guns=guns+1 elseif kind=="cash" then cash=cash+1 end
            end
        end
        metrics.scans=metrics.scans+1
        return {start=start~=nil,grab=grab~=nil,wall=wall~=nil,guns=guns,cash=cash,
                fireprompt=type(fireproximityprompt)=="function",money=readCash()}
    end
    return {
        supported=supported,placeId=PLACE,
        toggle=toggle,
        isOn=function(kind) return operations[kind] or false end,
        movement=function() travelMode=travelMode=="WALK" and "FAST" or "WALK"; return travelMode end,
        movementMode=function() return travelMode end,
        scan=scan,
        state=function() return statusText,metrics end,
        stop=function()
            for kind in pairs(operations) do operations[kind]=false end
            destroyed=true
        end,
    }
end

end)()

ctx.bronx3 = SquidBronx3(ctx)
local panel = SquidDashboard(ctx)
local gate = SquidKeyGate(ctx, function(data)
    ctx.authorized = true
    panel.open(data)
end)
panel.onLogout(function()
    ctx.state.session_token = nil
    ctx.save()
    ctx.authorized = false
    panel.close()
    gate.show("no_saved_key")
end)
gate.show()

local keyboardConnection = UserInputService.InputBegan:Connect(function(input, consumed)
    if not consumed and input.KeyCode == Enum.KeyCode.RightShift then panel.toggle() end
end)
table.insert(ctx.connections, keyboardConnection)

task.spawn(function()
    while screen.Parent and not ctx.shutdown do
        task.wait(180)
        if ctx.authorized and ctx.state.session_token then
            local result = ctx.resume()
            if result.valid then
                panel.updateLicense(result)
            elseif result.reason ~= "network" and result.reason ~= "rate_limit" then
                ctx.authorized = false
                panel.close()
                gate.show(result.reason)
            else
                panel.setConnectionStatus("LICENSE SERVER OFFLINE")
            end
        end
    end
end)
env.__SQUID_CLOSE = function()
    if ctx.shutdown then return end
    ctx.shutdown = true
    panel.close()
    if ctx.bronx3 then ctx.bronx3.stop() end
    for _, con in ipairs(ctx.connections) do pcall(function() con:Disconnect() end) end
    if screen.Parent then screen:Destroy() end
end
