#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public OnPluginStart()
{
	HookEvent("weapon_reload", reload);
}

public void reload(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	Handle hGamedata = LoadGameConfigFile("pistol_reload_fix");
	
	StartPrepSDKCall(SDKCall_Player);
	
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTerrorPlayer::DoAnimationEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	Handle DoAnimEvent = EndPrepSDKCall();
	
	delete hGamedata;
	
	char sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	
	if (strcmp(sWeaponName, "weapon_pistol_magnum", false) == 0 )
	{
		new weaponent = GetPlayerWeaponSlot(iClient, 1);
		if (weaponent > 0 && IsValidEntity(weaponent))
		{
			new pistolclip = GetEntProp(weaponent, Prop_Send, "m_iClip1");
			{
				if (pistolclip == 0)
				{
					SDKCall(DoAnimEvent, iClient, 4, 1);
				}
			}
		}
	}
	else if (strcmp(sWeaponName, "weapon_pistol", false) == 0 )
	{
		new weaponent = GetPlayerWeaponSlot(iClient, 1);
		if (weaponent > 0 && IsValidEntity(weaponent))
		{
			new pistolclip = GetEntProp(weaponent, Prop_Send, "m_iClip1");
			if (GetEntProp(weaponent, Prop_Send, "m_isDualWielding") > 0)
			{
				if (pistolclip <= 1)
				{
					SDKCall(DoAnimEvent, iClient, 4, 1);
				}
			}
			else if (pistolclip == 0)
			{
				SDKCall(DoAnimEvent, iClient, 4, 1);
			}
		}
	}
}