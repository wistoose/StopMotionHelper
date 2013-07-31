
MOD.Name = "Physical Bones";

function MOD:Save(entity)

	local count = entity:GetPhysicsObjectCount();
	if count <= 0 then return nil; end

	local data = {};

	for i = 0, count - 1 do

		local pb = entity:GetPhysicsObjectNum(i);
		local b = entity:TranslatePhysBoneToBone(i);

		local d = {};
		d.Pos = pb:GetPos();
		d.Ang = pb:GetAngles();
		d.Moveable = pb:IsMoveable();

		data[i] = d;

	end

	return data;

end

function MOD:Load(entity, data)

	local count = entity:GetPhysicsObjectCount();
	if count <= 0 then return; end --Shouldn't happen, but meh

	for i = 0, count - 1 do

		local pb = entity:GetPhysicsObjectNum(i);

		local d = data[i];
		pb:SetPos(d.Pos);
		pb:SetAngles(d.Ang);
		pb:EnableMotion(d.Moveable);
		pb:Wake();

	end

end

function MOD:LoadBetween(entity, data1, data2, percentage)

	local count = entity:GetPhysicsObjectCount();
	if count <= 0 then return; end --Shouldn't happen, but meh

	for i = 0, count - 1 do

		local pb = entity:GetPhysicsObjectNum(i);

		local d1 = data1[i];
		local d2 = data2[i];

		local Pos = SMH.LerpLinearVector(d1.Pos, d2.Pos, percentage);
		local Ang = SMH.LerpLinearAngle(d1.Ang, d2.Ang, percentage);

		pb:EnableMotion(false);

		pb:SetPos(Pos);
		pb:SetAngles(Ang);

		pb:Wake();

	end

end