#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_spawner;

init()
{
    level._effect["poltergeist"] = loadfx( "misc/fx_zombie_couch_effect" );
    
    level.multi_mule_kick_machine = getEnt("vending_additionalprimaryweapon", "targetname");
    level.multi_juggernog_machine = getEnt("vending_jugg", "targetname");
    level.multi_staminup_machine = getEnt("vending_marathon", "targetname");
    level.multi_speedcola_machine = getEnt("vending_sleight", "targetname");
    level.multi_quickrevive_machine = getEnt("vending_revive", "targetname");
    level.multi_doubletap_machine = getEnt("vending_doubletap", "targetname");
    
    level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
    level._game_module_point_adjustment = ::point_crusher_multiplier;
    level thread register_zombie_damage_callback( ::custom_zombie_damage_multiplier );
    
    level thread onPlayerConnect();
}

create_trigger_radius(hint_text, origin)
{
    trigger = spawn("trigger_radius", origin, 1, 70, 70);
    trigger setcursorhint("HINT_ACTIVATE");
    trigger sethintstring(hint_text);
    trigger setvisibletoall();
    return trigger;
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        self waittill("spawned_player");
        self reset_perk_values();
        self thread check_proximity_to_machines();
        self thread perk_bought_check();
    }
}

reset_perk_values()
{
    self.hasMuleKickOnce = false;
    self.multi_mule_kick_counter = 1;
    self.starting_mule_kick_price = 4000;
    self.mule_kick_price = self.starting_mule_kick_price;
    self.weapon_limit_counter = 3;
    self.original_mule_kick_machine_location = undefined;
    self.current_mule_kick_trigger = undefined;
    self.last_mule_kick_purchase_time = 0;
    self.can_buy_multi_mule = false;

    self.hasJuggernogOnce = false;
    self.multi_juggernog_counter = 1;
    self.starting_jugger_price = 5000;
    self.jugger_price = self.starting_jugger_price;
    self.original_jugger_machine_location = undefined;
    self.current_jugger_trigger = undefined;
    self.last_jugger_purchase_time = 0;
    self.can_buy_multi_jugger = false;

    self.hasJetpackOnce = false;
    self.jetpack_price = 4000;
    self.has_jetpack = false;
    self.original_staminup_machine_location = undefined;
    self.current_staminup_trigger = undefined;
    self.last_staminup_purchase_time = 0;
    self.can_buy_jetpack = false;

    self.hasPointCrusherOnce = false;
    self.multi_pointcrusher_counter = 0;
    self.starting_pointcrusher_price = 4000;
    self.pointcrusher_price = self.starting_pointcrusher_price;
    self.point_multiplier = 1;
    self.original_speedcola_machine_location = undefined;
    self.current_speedcola_trigger = undefined;
    self.last_speedcola_purchase_time = 0;
    self.can_buy_pointcrusher = false;

    self.has_muscle_milk = false;
    self.muscle_milk_price = 3000;
    self.muscle_milk_cooldown = false;
    self.original_quickrevive_machine_location = undefined;
    self.current_quickrevive_trigger = undefined;
    self.last_quickrevive_purchase_time = 0;
    self.can_buy_muscle_milk = false;

    self.hasPunchColaOnce = false;
    self.multi_punchcola_counter = 1;
    self.starting_punchcola_price = 5000;
    self.punchcola_price = self.starting_punchcola_price;
    self.punchcola_damage_level = 1;
    self.original_doubletap_machine_location = undefined;
    self.current_doubletap_trigger = undefined;
    self.last_doubletap_purchase_time = 0;
    self.can_buy_punchcola = false;

    self.machine_is_in_use = false;
    self.is_purchasing = false;
    self.num_perks = 0;
    self.perk_reminder = 0;
    self.perk_count = 0;
    self.perks_given = 0;
}

check_proximity_to_machines()
{
    self endon("disconnect");
    self endon("death");
    
    while(true)
    {
        if(self hasPerk("specialty_additionalprimaryweapon") && !self.is_purchasing)
            self check_perk_proximity("mule_kick", self.original_mule_kick_machine_location, self.last_mule_kick_purchase_time);
        
        if(self hasPerk("specialty_armorvest") && !self.is_purchasing)
            self check_perk_proximity("jugger", self.original_jugger_machine_location, self.last_jugger_purchase_time);
        
        if(self hasPerk("specialty_longersprint") && !self.is_purchasing)
            self check_perk_proximity("staminup", self.original_staminup_machine_location, self.last_staminup_purchase_time, self.has_jetpack);
        
        if(self hasPerk("specialty_fastreload") && !self.is_purchasing)
            self check_perk_proximity("speedcola", self.original_speedcola_machine_location, self.last_speedcola_purchase_time);
        
        if(self hasPerk("specialty_quickrevive") && !self.is_purchasing)
            self check_perk_proximity("quickrevive", self.original_quickrevive_machine_location, self.last_quickrevive_purchase_time, self.has_muscle_milk);

        if(self hasPerk("specialty_rof") && !self.is_purchasing)
            self check_perk_proximity("doubletap", self.original_doubletap_machine_location, self.last_doubletap_purchase_time);
        
        wait 0.2;
    }
}

check_perk_proximity(perk_type, machine_location, last_purchase_time, additional_condition)
{
    if(!isDefined(machine_location))
        return;
        
    if(distance(self.origin, machine_location) <= 70 && !self.machine_is_in_use && (!isDefined(additional_condition) || !additional_condition))
    {
        if(GetTime() - last_purchase_time >= 200)
        {
            if(perk_type == "mule_kick")
                self thread show_multi_mule_kick_prompt();
            else if(perk_type == "jugger")
                self thread show_multi_juggernog_prompt();
            else if(perk_type == "staminup")
                self thread show_staminup_jetpack_prompt();
            else if(perk_type == "speedcola")
                self thread show_speedcola_pointcrusher_prompt();
            else if(perk_type == "quickrevive")
                self thread show_muscle_milk_prompt();
            else if(perk_type == "doubletap")
                self thread show_punchcola_prompt();
        }
    }
    else
    {
        if(perk_type == "mule_kick" && isDefined(self.current_mule_kick_trigger))
        {
            self.current_mule_kick_trigger delete();
            self.current_mule_kick_trigger = undefined;
        }
        else if(perk_type == "jugger" && isDefined(self.current_jugger_trigger))
        {
            self.current_jugger_trigger delete();
            self.current_jugger_trigger = undefined;
        }
        else if(perk_type == "staminup" && isDefined(self.current_staminup_trigger))
        {
            self.current_staminup_trigger delete();
            self.current_staminup_trigger = undefined;
        }
        else if(perk_type == "speedcola" && isDefined(self.current_speedcola_trigger))
        {
            self.current_speedcola_trigger delete();
            self.current_speedcola_trigger = undefined;
        }
        else if(perk_type == "quickrevive" && isDefined(self.current_quickrevive_trigger))
        {
            self.current_quickrevive_trigger delete();
            self.current_quickrevive_trigger = undefined;
        }
        else if(perk_type == "doubletap" && isDefined(self.current_doubletap_trigger))
        {
            self.current_doubletap_trigger delete();
            self.current_doubletap_trigger = undefined;
        }
    }
}

show_perk_prompt_core(trigger_var, perk_name, price, machine_location, purchase_func, extra_condition)
{
    while(self isTouching(trigger_var) && self hasPerk(perk_name) && !self.machine_is_in_use && !self.is_purchasing && !extra_condition)
    {
        if(self useButtonPressed() && self.score >= price && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(trigger_var))
            {
                trigger_var delete();
                trigger_var = undefined;
            }
            if(distance(self.origin, machine_location) <= 70)
                self thread [[purchase_func]]();
            break;
        }
        else if(self useButtonPressed() && self.score < price)
        {
            if(distance(self.origin, machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
}

show_multi_mule_kick_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing || !self.can_buy_multi_mule)
        return;
    if(!isDefined(self.current_mule_kick_trigger))
        self.current_mule_kick_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Multi-Mule Kick [Cost: " + self.mule_kick_price + "]", self.original_mule_kick_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_mule_kick_trigger, "specialty_additionalprimaryweapon", self.mule_kick_price, self.original_mule_kick_machine_location, ::process_multi_mule_kick_purchase, false);
    if(isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger delete();
        self.current_mule_kick_trigger = undefined;
    }
}

show_multi_juggernog_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing || !self.can_buy_multi_jugger)
        return;
    if(!isDefined(self.current_jugger_trigger))
        self.current_jugger_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Multi-Juggernog [Cost: " + self.jugger_price + "]", self.original_jugger_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_jugger_trigger, "specialty_armorvest", self.jugger_price, self.original_jugger_machine_location, ::process_multi_juggernog_purchase, false);
    if(isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger delete();
        self.current_jugger_trigger = undefined;
    }
}

show_speedcola_pointcrusher_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_fastreload") || self.is_purchasing || !self.can_buy_pointcrusher)
        return;
    if(!isDefined(self.current_speedcola_trigger))
        self.current_speedcola_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Point Crusher [Cost: " + self.pointcrusher_price + "]", self.original_speedcola_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_speedcola_trigger, "specialty_fastreload", self.pointcrusher_price, self.original_speedcola_machine_location, ::process_speedcola_pointcrusher_purchase, false);
    if(isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger delete();
        self.current_speedcola_trigger = undefined;
    }
}

show_staminup_jetpack_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_longersprint") || self.is_purchasing || self.has_jetpack || !self.can_buy_jetpack)
        return;
    if(!isDefined(self.current_staminup_trigger))
        self.current_staminup_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Exo Suit [Cost: " + self.jetpack_price + "]", self.original_staminup_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_staminup_trigger, "specialty_longersprint", self.jetpack_price, self.original_staminup_machine_location, ::process_staminup_jetpack_purchase, self.has_jetpack);
    if(isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger delete();
        self.current_staminup_trigger = undefined;
    }
}

show_muscle_milk_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_quickrevive") || self.is_purchasing || self.has_muscle_milk || !self.can_buy_muscle_milk)
        return;
    if(!isDefined(self.current_quickrevive_trigger))
        self.current_quickrevive_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Muscle Milk [Cost: " + self.muscle_milk_price + "]", self.original_quickrevive_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_quickrevive_trigger, "specialty_quickrevive", self.muscle_milk_price, self.original_quickrevive_machine_location, ::process_muscle_milk_purchase, self.has_muscle_milk);
    if(isDefined(self.current_quickrevive_trigger))
    {
        self.current_quickrevive_trigger delete();
        self.current_quickrevive_trigger = undefined;
    }
}

show_punchcola_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_rof") || self.is_purchasing || !self.can_buy_punchcola)
        return;
    if(!isDefined(self.current_doubletap_trigger))
        self.current_doubletap_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Punch-a-Cola [Cost: " + self.punchcola_price + "]", self.original_doubletap_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_doubletap_trigger, "specialty_rof", self.punchcola_price, self.original_doubletap_machine_location, ::process_punchcola_purchase, false);
    if(isDefined(self.current_doubletap_trigger))
    {
        self.current_doubletap_trigger delete();
        self.current_doubletap_trigger = undefined;
    }
}

process_perk_purchase(perk_name, price, machine_location, bottle_name, additional_condition)
{
    if(!self hasPerk(perk_name) || self.is_purchasing)
        return;
    
    if(isDefined(additional_condition) && additional_condition)
        return;
    
    if(!isDefined(machine_location) || distance(self.origin, machine_location) > 70)
        return;
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    self giveWeapon(bottle_name);
    self switchToWeapon(bottle_name);
    self waittill("weapon_change_complete");
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle_name);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

process_multi_mule_kick_purchase()
{
    self process_perk_purchase("specialty_additionalprimaryweapon", self.mule_kick_price, self.original_mule_kick_machine_location, "zombie_perk_bottle_additionalprimaryweapon");
    self.weapon_limit_counter++;
    self.multi_mule_kick_counter++;
    self.mule_kick_price = self.starting_mule_kick_price * self.multi_mule_kick_counter;
    self.last_mule_kick_purchase_time = GetTime();
    self iprintln("^1Mule Kick Level " + self.multi_mule_kick_counter + "\n^2Weapon Limit increased to " + self.weapon_limit_counter);
}

process_multi_juggernog_purchase()
{
    self process_perk_purchase("specialty_armorvest", self.jugger_price, self.original_jugger_machine_location, "zombie_perk_bottle_jugg");
    self.maxhealth += 150;
    self.health = self.maxhealth;
    self.multi_juggernog_counter++;
    self.jugger_price = self.starting_jugger_price * self.multi_juggernog_counter;
    self.last_jugger_purchase_time = GetTime();
    self.hits_counter = int(self.maxhealth / 50);
    self iprintln("^1Juggernog Level " + self.multi_juggernog_counter + "\n^2Health increased to " + self.maxhealth + "\n^8Now you resist " + self.hits_counter + " Hits!");
}

process_speedcola_pointcrusher_purchase()
{
    self process_perk_purchase("specialty_fastreload", self.pointcrusher_price, self.original_speedcola_machine_location, "zombie_perk_bottle_sleight");
    self.multi_pointcrusher_counter++;
    self.point_multiplier = self.multi_pointcrusher_counter + 1;
    self.pointcrusher_price = self.starting_pointcrusher_price * self.point_multiplier;
    self.last_speedcola_purchase_time = GetTime();
    self iprintln("^1Point Crusher Level " + self.multi_pointcrusher_counter + "\n^2Points Multiplier increased to x" + self.point_multiplier);
}

process_staminup_jetpack_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.jetpack_price, self.original_staminup_machine_location, "zombie_perk_bottle_marathon", self.has_jetpack);
    self.has_jetpack = true;
    self.last_staminup_purchase_time = GetTime();
    self iprintln("^2Exo Suit Acquired!\n^3Now you can Boost yourself!\n^1If you Double Jump and Crouch you can cause an explosion!");
    self thread init_jetpack();
}

process_muscle_milk_purchase()
{
    self process_perk_purchase("specialty_quickrevive", self.muscle_milk_price, self.original_quickrevive_machine_location, "zombie_perk_bottle_revive", self.has_muscle_milk);
    self.has_muscle_milk = true;
    self.last_quickrevive_purchase_time = GetTime();
    self iprintln("^2Muscle Milk Acquired!\n^3Now you can electrocute when you use your melee weapon.\n^1Cooldown: 15 seconds");
    self thread monitor_muscle_milk();
}

process_punchcola_purchase()
{
    self process_perk_purchase("specialty_rof", self.punchcola_price, self.original_doubletap_machine_location, "zombie_perk_bottle_doubletap");
    self.punchcola_damage_level++;
    self.multi_punchcola_counter++;
    self.punchcola_price = self.starting_punchcola_price * self.multi_punchcola_counter;
    self.last_doubletap_purchase_time = GetTime();
    self iprintln("^1Punch-a-Cola Level " + (self.punchcola_damage_level - 1) + "\n^2Damage Multiplier: x" + self.punchcola_damage_level);
}

perk_bought_check()
{
    self endon("death");
    self endon("disconnect");
    self thread monitor_perk_status();
    
    for(;;)
    {
        self.perk_reminder = self.num_perks;
        self waittill("perk_acquired");
        
        if(self hasPerk("specialty_additionalprimaryweapon") && !isDefined(self.original_mule_kick_machine_location))
        {
            self.original_mule_kick_machine_location = level.multi_mule_kick_machine.origin;
            self.last_mule_kick_purchase_time = GetTime();
            self.can_buy_multi_mule = false; wait 1; self.can_buy_multi_mule = true;
        }
        
        if(self hasPerk("specialty_armorvest") && !isDefined(self.original_jugger_machine_location))
        {
            self.original_jugger_machine_location = level.multi_juggernog_machine.origin;
            self.last_jugger_purchase_time = GetTime();
            self.can_buy_multi_jugger = false; wait 1; self.can_buy_multi_jugger = true;
        }
        
        if(self hasPerk("specialty_longersprint") && !isDefined(self.original_staminup_machine_location))
        {
            self.original_staminup_machine_location = level.multi_staminup_machine.origin;
            self.last_staminup_purchase_time = GetTime();
            self.can_buy_jetpack = false; wait 1; self.can_buy_jetpack = true;
        }
        
        if(self hasPerk("specialty_fastreload") && !isDefined(self.original_speedcola_machine_location))
        {
            self.original_speedcola_machine_location = level.multi_speedcola_machine.origin;
            self.last_speedcola_purchase_time = GetTime();
            self.can_buy_pointcrusher = false; wait 1; self.can_buy_pointcrusher = true;
        }
        
        if(self hasPerk("specialty_quickrevive") && !isDefined(self.original_quickrevive_machine_location))
        {
            if (getdvar("mapname") == "zm_tomb") 
            {
               self.original_quickrevive_machine_location = (2355.26, 5033.44, -303.875);
            }
            else
            {
               self.original_quickrevive_machine_location = level.multi_quickrevive_machine.origin;
            }
            self.last_quickrevive_purchase_time = GetTime();
            self.can_buy_muscle_milk = false; wait 1; self.can_buy_muscle_milk = true;
        }

        if(self hasPerk("specialty_rof") && !isDefined(self.original_doubletap_machine_location))
        {
            self.original_doubletap_machine_location = level.multi_doubletap_machine.origin;
            self.last_doubletap_purchase_time = GetTime();
            if(!isDefined(self.punchcola_damage_level)) self.punchcola_damage_level = 1;
            self.can_buy_punchcola = false; wait 1; self.can_buy_punchcola = true;
        }
        
        n = 1;
        if(!(self.num_perks > self.perk_reminder))
        {
            n = (self.num_perks - self.perk_reminder);
            self.num_perks = (self.perk_reminder + n);
        }
        self.perk_reminder = self.num_perks;
        self.perk_count += n;
    }
}

monitor_perk_status()
{
    self endon("death");
    self endon("disconnect");
    
    while(true)
    {
        if(!self hasPerk("specialty_additionalprimaryweapon"))
        {
            self.multi_mule_kick_counter = 1;
            self.mule_kick_price = self.starting_mule_kick_price;
            self.original_mule_kick_machine_location = undefined;
            self.last_mule_kick_purchase_time = 0;
            self.weapon_limit_counter = 3;
            if(isDefined(self.current_mule_kick_trigger)) { self.current_mule_kick_trigger delete(); self.current_mule_kick_trigger = undefined; }
        }
        
        if(!self hasPerk("specialty_armorvest"))
        {
            self.multi_juggernog_counter = 1;
            self.jugger_price = self.starting_jugger_price;
            self.original_jugger_machine_location = undefined;
            self.last_jugger_purchase_time = 0;
            if(isDefined(self.current_jugger_trigger)) { self.current_jugger_trigger delete(); self.current_jugger_trigger = undefined; }
        }
        
        if(!self hasPerk("specialty_longersprint"))
        {
            self.has_jetpack = false;
            self.original_staminup_machine_location = undefined;
            self.last_staminup_purchase_time = 0;
            if(isDefined(self.current_staminup_trigger)) { self.current_staminup_trigger delete(); self.current_staminup_trigger = undefined; }
        }
        
        if(!self hasPerk("specialty_fastreload"))
        {
            self.multi_pointcrusher_counter = 0;
            self.pointcrusher_price = self.starting_pointcrusher_price;
            self.point_multiplier = 1;
            self.original_speedcola_machine_location = undefined;
            self.last_speedcola_purchase_time = 0;
            if(isDefined(self.current_speedcola_trigger)) { self.current_speedcola_trigger delete(); self.current_speedcola_trigger = undefined; }
        }
        
        if(!self hasPerk("specialty_quickrevive"))
        {
            self.has_muscle_milk = false;
            self.original_quickrevive_machine_location = undefined;
            self.last_quickrevive_purchase_time = 0;
            if(isDefined(self.current_quickrevive_trigger)) { self.current_quickrevive_trigger delete(); self.current_quickrevive_trigger = undefined; }
        }

        if(!self hasPerk("specialty_rof"))
        {
            self.multi_punchcola_counter = 1;
            self.punchcola_price = self.starting_punchcola_price;
            self.punchcola_damage_level = 1;
            self.original_doubletap_machine_location = undefined;
            self.last_doubletap_purchase_time = 0;
            if(isDefined(self.current_doubletap_trigger)) { self.current_doubletap_trigger delete(); self.current_doubletap_trigger = undefined; }
        }
        
        wait 0.5;
    }
}

custom_get_player_weapon_limit(player)
{
    weapon_limit = 2;
    if(player hasPerk("specialty_additionalprimaryweapon"))
        weapon_limit = player.weapon_limit_counter;
    else 
    {
        weapons = player getWeaponsListPrimaries();
        if(weapons.size > 2) player takeWeapon(weapons[2]);
    }
    return weapon_limit;
}

init_jetpack()
{
    self endon("disconnect");
    level endon("end_game");
    
    self.sprint_boost = 0; self.jump_boost = 0; self.slam_boost = 0;
    self.exo_boost = 100; self.is_flying_jetpack = 0;
    self.last_boost_time = 0; self.boost_cooldown = false; self.hover_active = false;
    
    self thread monitor_exo_boost();
    self thread handle_jetpack_movement();
}

handle_jetpack_movement()
{
    self endon("disconnect");
    level endon("end_game");
    
    while(1)
    {
        if(self.has_jetpack && !self isonground())
        {
            if(self sprintbuttonpressed() || self jumpbuttonpressed()) { wait_network_frame(); continue; }
            
            self.sprint_boost = 0; self.jump_boost = 0; self.slam_boost = 0;
            
            while(!self isonground())
            {
                if(self.exo_boost >= 20 && self.jump_boost < 1 && self jumpbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.jump_boost++;
                    earthquake(0.22, 0.9, self.origin, 850);
                    self setvelocity((self getvelocity()[0], self getvelocity()[1], 350));
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self.exo_boost >= 20 && self.sprint_boost < 1 && self sprintbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.sprint_boost++;
                    angles = self getplayerangles(); direction = anglestoforward(angles);
                    current_vel = self getvelocity();
                    boost_vel = (current_vel[0] + direction[0] * 600, current_vel[1] + direction[1] * 600, current_vel[2]);
                    earthquake(0.22, 0.9, self.origin, 850); self setvelocity(boost_vel);
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self adsbuttonpressed() && self.exo_boost > 0)
                {
                    current_vel = self getvelocity();
                    if(current_vel[2] < 0)
                    {
                        hover_vel = (current_vel[0] * 0.95, current_vel[1] * 0.95, current_vel[2] * 0.15);
                        self setvelocity(hover_vel); self.exo_boost = max(0, self.exo_boost - 0.5);
                    }
                }
                
                if(self.exo_boost >= 30 && self.slam_boost < 1 && self.jump_boost > 0 && self stancebuttonpressed())
                {
                    self.slam_boost++; self setvelocity((self getvelocity()[0], self getvelocity()[1], -200));
                    self thread land(); self.exo_boost -= 30; self thread monitor_exo_boost();
                }
                
                wait_network_frame();
            }
            
            if(self.slam_boost > 0)
            {
                self enableinvulnerability();
                radiusdamage(self.origin, 200, 3000, 500, self, "MOD_GRENADE_SPLASH");
                self disableinvulnerability();
                self playsound("zmb_phdflop_explo");
                fx = loadfx("explosions/fx_default_explosion"); playfx(fx, self.origin);
            }
        }
        wait_network_frame();
    }
}

monitor_exo_boost()
{
    self endon("disconnect");
    self notify("boostMonitor");
    self endon("boostMonitor");
    
    while(1)
    {
        while(self.exo_boost >= 100) wait_network_frame();
        wait 3;
        while(self.exo_boost < 100) { self.exo_boost = self.exo_boost + 5; wait 0.25; }
    }
}

land()
{
    self endon("disconnect");
    while(!self isonground()) wait_network_frame();
    self.is_flying_jetpack = 0;
}

point_crusher_multiplier(player, zombie_team, player_points)
{
    if(isDefined(player.multi_pointcrusher_counter) && player.multi_pointcrusher_counter > 0)
    {
        player_points *= player.multi_pointcrusher_counter;
        player maps\mp\zombies\_zm_score::add_to_player_score(player_points);
        player.pers["score"] = player.score;
    }
}

monitor_muscle_milk()
{
    self endon("disconnect");
    self endon("death");
    self thread watch_for_melee();
    
    while(self.has_muscle_milk)
    {
        if(!self hasPerk("specialty_quickrevive")) { self.has_muscle_milk = false; break; }
        wait 0.1;
    }
}

watch_for_melee()
{
    self endon("disconnect");
    self endon("death");
    
    while(self.has_muscle_milk)
    {
        if(self meleeButtonPressed() && !self.muscle_milk_cooldown) self thread muscle_milk_attack();
        wait 0.05;
    }
}

muscle_milk_attack()
{
    self.muscle_milk_cooldown = true;
    playfxontag(level._effect["poltergeist"], self, "J_SpineUpper");
    self playsound("zmb_turbine_explo");
    
    zombies = getAiArray(level.zombie_team);
    foreach(zombie in zombies)
    {
        if(distance(self.origin, zombie.origin) < 150) zombie doDamage(zombie.health + 777, zombie.origin, self);
    }
    
    self thread muscle_milk_cooldown_timer();
}

muscle_milk_cooldown_timer()
{
    wait 15;
    if(self.has_muscle_milk) self iprintln("^2Muscle Milk Ready!");
    self.muscle_milk_cooldown = false;
}

custom_zombie_damage_multiplier(mod, hit_location, hit_origin, player, amount)  
{  
    if (isdefined(player) && isplayer(player) && player hasPerk("specialty_rof") && isDefined(player.punchcola_damage_level) && player.punchcola_damage_level > 1)
    {  
        multiplier = player.punchcola_damage_level;
        extra_damage = amount * (multiplier - 1.0);  
        if (extra_damage > 0) self dodamage(extra_damage, hit_origin, player, player, hit_location, mod);  
    }  
    return false;
}