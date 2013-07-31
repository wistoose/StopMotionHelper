
if !game.SinglePlayer() then return end

include("shared.lua");
include("server/easing.lua");
include("server/eyetarget.lua");
include("server/modifiers.lua");

AddCSLuaFile("client.lua");
AddCSLuaFile("shared.lua");
AddCSLuaFile("client/menu.lua");

local FingersAll = 5 * 3 * 2

SMH.frames = {} //You can get the frame count with #SMH.frames
SMH.CurPic = 0 //We only need CurPic value in the server

SMH.AddNetFunc("clAddFrame")
SMH.AddNetFunc("clRemFrame")
SMH.AddNetFunc("clSelectEnt")
SMH.AddNetFunc("clDeselectEnt")
SMH.AddNetFunc("clSetFrame")
SMH.AddNetFunc("clLoad")
SMH.AddNetFunc("clLoadAddEnt")

//--
//Taken from faceposer.lua
local function IsUselessFaceFlex( strName )

	if ( strName == "gesture_rightleft" ) then return true end
	if ( strName == "gesture_updown" ) then return true end
	if ( strName == "head_forwardback" ) then return true end
	if ( strName == "chest_rightleft" ) then return true end
	if ( strName == "body_rightleft" ) then return true end
	if ( strName == "eyes_rightleft" ) then return true end
	if ( strName == "eyes_updown" ) then return true end
	if ( strName == "head_tilt" ) then return true end
	if ( strName == "head_updown" ) then return true end
	if ( strName == "head_rightleft" ) then return true end
	
	return false

end
//--

local function RagHasEyes(ent)
	local Eyes = ent:LookupAttachment("eyes")
	if Eyes == 0 then return false end
	return true
end

util.AddNetworkString("smhClientLoad");

hook.Add("InitPostEntity","smhServerLoad",function()
timer.Create("smhServerLoad",1,1,function()

local Thread = ents.FindByClass("smh_thread")[1]
-- print(Thread);
if IsValid(Thread) then
	-- print("SENT");

	SMH.Ents = Thread:GetEnts();
	SMH.frames = Thread:GetFrames();
	
	net.Start("smhClientLoad");
	
	net.WriteInt(#SMH.Ents, 32);
	
	for i,v in ipairs(SMH.Ents) do
		net.WriteEntity(v);
	end
	
	net.WriteInt(#SMH.frames, 32);
	
	net.Send(player.GetByID(1));
	
	SMH.ThreadUpdate = true;
else
	Thread = ents.Create("smh_thread")
	Thread:Spawn()
	Thread.Ents = {}
	Thread.frames = {}
	SMH.ThreadUpdate = true
end

local rags = ents.FindByClass("prop_ragdoll");
local props = ents.FindByClass("prop_physics");
local Ents = {};
table.Add(Ents, rags);
table.Add(Ents, props);

for k,v in pairs(Ents) do
	if IsValid(v.smhGhost) then
		v.smhGhost:SetNotSolid(true)
		v.smhGhost:SetColor(Color(255,255,255,0))
		v.smhGhost:SetRenderMode(RENDERMODE_TRANSALPHA)
		v.smhGhost:DrawShadow(false)
	end
end

end)
end)

local function UpdateFramecount()
	if !SMH.frames then return end
	
	local framec = GetGlobalInt("smhFrameCount")
	if !framec then return end
	if framec == #SMH.frames then return end
	SetGlobalInt("smhFrameCount",#SMH.frames)
end
hook.Add("Think","smhUpdateFramecount",UpdateFramecount)

//Setting up first frame on server
SMH.frames[1] = {}
SMH.frames[1].Pics = 10
SMH.frames[1].StartSlow = 0.0
SMH.frames[1].EndSlow = 0.0
//SMH.frames[1].Smooth = false

function SMH.svSelectEnt(Self)
	if !IsValid(Self) then return false end
	if Self:GetPhysicsObjectCount() <= 0 then return false end
	if table.HasValue(SMH.Ents,Self) then return false end
	if !Self.smhFrames then
		Self.smhFrames = {}
	end
	table.insert(SMH.Ents,Self)
	SMH.clSelectEnt(Self)
	Self:smhAddGhost()
	return true
end

function SMH.svDeselectEnt(Self)
	if Self == NULL or !Self:IsValid() then return false end
	if !table.HasValue(SMH.Ents,Self) then return false end
	for k,v in pairs(SMH.Ents) do
		if v == Self then
			v:smhRemoveGhost()
			table.remove(SMH.Ents,k)
			SMH.clDeselectEnt(v)
			return true
		end
	end
	return false
end

function SMH.svAddFrame(f)
	table.insert(SMH.frames,f+1,{})
	SMH.frames[f+1].Pics = GetConVar("smh_picsadd"):GetInt()
	SMH.frames[f+1].StartSlow = GetConVar("smh_startslow"):GetFloat()
	SMH.frames[f+1].EndSlow = GetConVar("smh_endslow"):GetFloat()
	//SMH.frames[f+1].Smooth = GetConVar("smh_moverounded"):GetBool()
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhAddFrame(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
	SMH.CurFrame = f+1
	SMH.CurPic = 0
	SMH.clAddFrame(f)
end

function SMH.svRemFrame(f)
	table.remove(SMH.frames,f)
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhRemFrame(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
	SMH.clRemFrame(f)
end

function SMH.svRecFrame(f)
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then	
			v:smhRecFrame(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
end

function SMH.svClearFrame(f)
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhClearFrame(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
end

//Moving a frame down means changing positions
//between current and next frame.
//Moving up is between current and previous frame.
function SMH.svMoveFrameUp(f)
	if SMH.CurFrame <= 1 then return end
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhMoveFrameUp(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
	local FT = SMH.frames[f]
	table.remove(SMH.frames,f)
	table.insert(SMH.frames,f-1,FT)
	SMH.svSetFrame(f-1)
end
function SMH.svMoveFrameDown(f)
	if SMH.CurFrame >= #SMH.frames then return end
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhMoveFrameDown(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
	local FT = SMH.frames[f]
	table.remove(SMH.frames,f)
	table.insert(SMH.frames,f+1,FT)
	SMH.svSetFrame(f+1)
end

/*function SMH.svToggleSmooth(f,b)
	if !SMH.frames[f] then return end
	SMH.frames[f].Smooth = b
end*/

function SMH.svSetSS(f,val)
	if !SMH.frames[f] then return end
	SMH.frames[f].StartSlow = val
end

function SMH.svSetES(f,val)
	if !SMH.frames[f] then return end
	SMH.frames[f].EndSlow = val
end

function SMH.svSetFramePB(f,pb)
	if !SMH.frames[f] then return end
	SMH.frames[f].Pics = pb
end

function SMH.svEnableGhosts()
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhEnableGhost()
			v:smhSetGhostFrame(SMH.CurFrame)
		else
			table.remove(SMH.Ents,k)
		end
	end
end
function SMH.svDisableGhosts()
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhDisableGhost()
		else
			table.remove(SMH.Ents,k)
		end
	end
end

function SMH.svSetFrame(f)
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhEnableGhost()
			v:smhSetGhostFrame(f)
			v:smhSetFrame(f)
		else
			table.remove(SMH.Ents,k)
		end
	end
	SMH.CurFrame = f
	SMH.CurPic = 0
	//local smooth = 0
	local ss = SMH.frames[f].StartSlow
	local es = SMH.frames[f].EndSlow
	//if SMH.frames[f].Smooth then smooth = 1 end
	SMH.clSetFrame(f,SMH.frames[f].Pics/*,smooth*/,ss,es)
end

function SMH.svSetPic(f,pic)
	local p = pic / (SMH.frames[f].Pics+1)
	for k,v in pairs(SMH.Ents) do
		if IsValid(v) then
			v:smhDisableGhost()
			v:smhSetPic(f,p/*,SMH.frames[f].Smooth*/,SMH.frames[f].StartSlow,SMH.frames[f].EndSlow)
		else
			table.remove(SMH.Ents,k)
		end
	end
	SMH.CurFrame = f
	SMH.CurPic = pic
end

function SMH.svNextPic()
	local curframe = SMH.CurFrame
	local curpic = SMH.CurPic
	local frame = curframe
	local pic = curpic + 1
	if pic > SMH.frames[frame].Pics or frame == #SMH.frames then
		frame = frame + 1
		pic = 0
		if frame > #SMH.frames then
			frame = 1
		end
	end
	SMH.svSetPic(frame,pic)
	//local smooth = 0
	local ss = SMH.frames[frame].StartSlow
	local es = SMH.frames[frame].EndSlow
	//if SMH.frames[frame].Smooth then smooth = 1 end
	if frame != curframe then SMH.clSetFrame(frame,SMH.frames[frame].Pics/*,smooth*/,ss,es) end
end

function SMH.svPrevPic()
	local curframe = SMH.CurFrame
	local curpic = SMH.CurPic
	local frame = curframe
	local pic = curpic - 1
	if pic < 0 then
		frame = frame - 1
		if frame < 1 then
			frame = #SMH.frames
		end
		pic = SMH.frames[frame].Pics
	elseif pic > 0 and frame == #SMH.frames then
		pic = 0
	end
	SMH.svSetPic(frame,pic)
	//local smooth = 0
	local ss = SMH.frames[frame].StartSlow
	local es = SMH.frames[frame].EndSlow
	//if SMH.frames[frame].Smooth then smooth = 1 end
	if frame != curframe then SMH.clSetFrame(frame,SMH.frames[frame].Pics/*,smooth*/,ss,es) end
end

function smhPNextPic(pl,cmd,args)
	if timer.Exists("smh_NPPic") then
		timer.Remove("smh_NPPic")
	end
	SMH.svNextPic()
	timer.Create("smh_NPPic",GetConVar("smh_cycletick"):GetFloat(),0,function()
		SMH.svNextPic()
	end)
end
function smhNNextPic(pl,cmd,args)
	if timer.Exists("smh_NPPic") then
		timer.Remove("smh_NPPic")
	end
end

function smhPPrevPic(pl,cmd,args)
	if timer.Exists("smh_NPPic") then
		timer.Remove("smh_NPPic")
	end
	SMH.svPrevPic()
	timer.Create("smh_NPPic",GetConVar("smh_cycletick"):GetFloat(),0,function()
		SMH.svPrevPic()
	end)
end
function smhNPrevPic(pl,cmd,args)
	if timer.Exists("smh_NPPic") then
		timer.Remove("smh_NPPic")
	end
end

local function doJpeg(playa)
end

function smhMakeJPEG(pl,cmd,args)
	if !timer.Exists("smhJPEG") then
		SMH.svSetPic(1,0)
		pl:EmitSound("buttons/blip1.wav")
		timer.Create("smhJPEG",1.0,0,function()
			pl:ConCommand("jpeg")
			timer.Create("smhJPEG2",0.1,1,function()
				if SMH.CurFrame < #SMH.frames then
					SMH.svNextPic()
				else
					timer.Remove("smhJPEG")
					pl:EmitSound("buttons/button1.wav")
				end
			end)
		end)
	else
		timer.Remove("smhJPEG")
		pl:EmitSound("buttons/button1.wav")
	end
end

concommand.Add("+smh_nextpic",smhPNextPic)
concommand.Add("-smh_nextpic",smhNNextPic)
concommand.Add("+smh_prevpic",smhPPrevPic)
concommand.Add("-smh_prevpic",smhNPrevPic)
concommand.Add("smh_makejpeg",smhMakeJPEG)

/*local function cmdGetBones(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	for i=0,e:GetPhysicsObjectCount()-1 do
		Msg(i.." = "..e:GetBoneName(e:TranslatePhysBoneToBone(i)).."\n")
	end
end
concommand.Add("smh_targetbones",cmdGetBones)

local function cmdSetBoneCap(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] or !args[2] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	local po = e:GetPhysicsObjectNum(args[1])
	if po == NULL or !po:IsValid() then
		print("Invalid physics bone.")
		return
	end
	e:SetNetworkedBool("smh_cap_bone"..args[1],tobool(args[2]))
	Msg("Capping of bone "..args[1].." set to "..tostring(tobool(args[2]))..".\n")
end
local function cmdSetAllBoneCaps(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	for i=0,e:GetPhysicsObjectCount()-1 do
		e:SetNetworkedBool("smh_cap_bone"..i,tobool(args[1]))
	end
	Msg("All bone caps set to "..tostring(tobool(args[1]))..".\n")
end
concommand.Add("smh_setbonecap",cmdSetBoneCap)
concommand.Add("smh_setallbonecaps",cmdSetAllBoneCaps)

local function cmdSetFingerCap(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	e:SetNetworkedBool("smh_cap_fingers",tobool(args[1]))
	Msg("Finger capping set to "..tostring(tobool(args[1]))..".\n")
end
local function cmdSetFlexCap(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	e:SetNetworkedBool("smh_cap_flexes",tobool(args[1]))
	Msg("Flex capping set to "..tostring(tobool(args[1]))..".\n")
end
local function cmdSetEyeCap(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	e:SetNetworkedBool("smh_cap_eyes",tobool(args[1]))
	Msg("Eye capping set to "..tostring(tobool(args[1]))..".\n")
end
local function cmdSetColorCap(pl,cmd,args)
	local e = pl:GetEyeTrace().Entity
	if e == NULL or !e:IsValid() then return end
	if !args[1] then return end
	if !e.smh then
		print("Entity not selected.")
		return
	end
	e:SetNetworkedBool("smh_cap_color",tobool(args[1]))
	Msg("Color capping set to "..tostring(tobool(args[1]))..".\n")
end
concommand.Add("smh_setfingercap",cmdSetFingerCap)
concommand.Add("smh_setflexcap",cmdSetFlexCap)
concommand.Add("smh_seteyecap",cmdSetEyeCap)
concommand.Add("smh_setcolorcap",cmdSetColorCap)*/

Msg("SMH server initialized.\n")
