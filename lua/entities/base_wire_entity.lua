AddCSLuaFile()
DEFINE_BASECLASS( "base_gmodentity" )
ENT.Type = "anim"
ENT.PrintName       = "Wire Unnamed Ent"
ENT.Purpose = "Base for all wired SEnts"
ENT.RenderGroup		= RENDERGROUP_OPAQUE//RENDERGROUP_TRANSLUCENT//RENDERGROUP_BOTH
ENT.WireDebugName	= "No Name"
ENT.Spawnable = false
ENT.AdminOnly = false


-- Shared
ENT.IsWire = true
ENT.OverlayText = ""

function ENT:GetOverlayText()
	return self.OverlayText
end

function ENT:SetOverlayText( txt )
	self.OverlayText = txt
end

if CLIENT then 
	local wire_drawoutline = CreateClientConVar("wire_drawoutline", 1, true, false)

	function ENT:Initialize()
		self.NextRBUpdate = CurTime() + 0.25
	end

	function ENT:Draw()
		self:DoNormalDraw()
		Wire_Render(self)
		if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then 
			-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
			Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false ) 
		end
	end

	function ENT:DoNormalDraw(nohalo, notip)
		local trace = LocalPlayer():GetEyeTrace()
		local looked_at = trace.Entity == self and trace.Fraction * 16384 < 256
		if not nohalo and wire_drawoutline:GetBool() and looked_at then
			if self.RenderGroup == RENDERGROUP_OPAQUE then
				self.OldRenderGroup = self.RenderGroup
				self.RenderGroup = RENDERGROUP_TRANSLUCENT
			end
			self:DrawEntityOutline()
			self:DrawModel()
		else
			if self.OldRenderGroup then
				self.RenderGroup = self.OldRenderGroup
				self.OldRenderGroup = nil
			end
			self:DrawModel()
		end
		if not notip and looked_at then
			self:DrawTip()
		end
	end

	function ENT:DrawTip(text)
		text = text or self:GetOverlayText()
		local name = self:GetNetworkedString("WireName")
		local plyname = self:GetNetworkedString("FounderName")
		
		text = string.format("- %s -\n%s\n(%s)", name ~= "" and name or self.PrintName, text, plyname)
		AddWorldTip(nil,text,nil,self:GetPos(),nil)
	end

	function ENT:Think()
		if (CurTime() >= (self.NextRBUpdate or 0)) then
			self.NextRBUpdate = CurTime() + math.random(30,100)/10 --update renderbounds every 3 to 10 seconds
			Wire_UpdateRenderBounds(self)
		end
	end

	local halos = {}
	local halos_inv = {}

	function ENT:DrawEntityOutline()
		if halos_inv[self] then return end
		halos[#halos+1] = self
		halos_inv[self] = true
	end

	hook.Add("PreDrawHalos", "Wiremod_overlay_halos", function()
		if #halos == 0 then return end
		halo.Add(halos, Color(100,100,255), 3, 3, 1, true, true)
		halos = {}
		halos_inv = {}
	end)

	net.Receive( "WireOverlay", function(length)
		local ent = net.ReadEntity()
		ent.OverlayText = net.ReadString()
	end)
	
	return  -- No more client
end

-- Server

util.AddNetworkString("WireOverlay")

local playerOverlays = {}
timer.Create("WireOverlayUpdate", 0.1, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		local ent = ply:GetEyeTrace().Entity
		if not IsValid(ent) or not ent.IsWire then continue end
		playerOverlays[ply] = playerOverlays[ply] or {}
		if playerOverlays[ply][ent] != ent.OverlayText then
			playerOverlays[ply][ent] = ent.OverlayText
			net.Start("WireOverlay")
				net.WriteEntity(ent)
				net.WriteString(ent.OverlayText)
			net.Send(ply)
		end
	end
end)

function ENT:OnRemove()
	Wire_Remove(self)
end

function ENT:OnRestore()
    Wire_Restored(self)
end

function ENT:BuildDupeInfo()
	return WireLib.BuildDupeInfo(self)
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	WireLib.ApplyDupeInfo( ply, ent, info, GetEntByID )
end

function ENT:PreEntityCopy()
	//build the DupeInfo table and save it as an entity mod
	local DupeInfo = self:BuildDupeInfo()
	if(DupeInfo) then
		duplicator.StoreEntityModifier(self,"WireDupeInfo",DupeInfo)
	end
end

function ENT:PostEntityPaste(Player,Ent,CreatedEntities)
	//apply the DupeInfo
	if(Ent.EntityMods and Ent.EntityMods.WireDupeInfo) then
		Ent:ApplyDupeInfo(Player, Ent, Ent.EntityMods.WireDupeInfo, function(id) return CreatedEntities[id] end)
	end
end
