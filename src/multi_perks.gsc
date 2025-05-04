#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;

init()
{
    level._effect["poltergeist"] = loadfx( "misc/fx_zombie_couch_effect" );
    level._effect["multi_mule_kick"] = loadfx("misc/fx_zombie_cola_arsenal_on");
    level._effect["multi_juggernog"] = loadfx("misc/fx_zombie_cola_jugg_on");
    level._effect["multi_staminup"] = loadfx("misc/fx_zombie_cola_staminup_on");
    level._effect["multi_speedcola"] = loadfx("misc/fx_zombie_cola_speed_on");
    
    level.multi_mule_kick_machine = getEnt("vending_additionalprimaryweapon", "targetname");
    level.multi_juggernog_machine = getEnt("vending_jugg", "targetname");
    level.multi_staminup_machine = getEnt("vending_marathon", "targetname");
    level.multi_speedcola_machine = getEnt("vending_sleight", "targetname");
    level.multi_quickrevive_machine = getEnt("vending_revive", "targetname");
    
    level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
    level._game_module_point_adjustment = ::point_crusher_multiplier;
    
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

    self.hasJuggernogOnce = false;
    self.multi_juggernog_counter = 1;
    self.starting_jugger_price = 5000;
    self.jugger_price = self.starting_jugger_price;

    self.hasJetpackOnce = false;
    self.jetpack_price = 4000;
    self.has_jetpack = false;

    self.hasPointCrusherOnce = false;
    self.multi_pointcrusher_counter = 0;
    self.starting_pointcrusher_price = 4000;
    self.pointcrusher_price = self.starting_pointcrusher_price;
    self.point_multiplier = 1;
    self.original_speedcola_machine_location = undefined;
    self.current_speedcola_trigger = undefined;
    self.last_speedcola_purchase_time = 0;
    self.has_pointcrusher = false;

    self.has_muscle_milk = false;
    self.muscle_milk_price = 3000;
    self.muscle_milk_cooldown = false;
    self.original_quickrevive_machine_location = undefined;
    self.current_quickrevive_trigger = undefined;
    self.last_quickrevive_purchase_time = 0;

    self.machine_is_in_use = false;
    self.can_buy_multi_mule = false;
    self.can_buy_multi_jugger = false;
    self.perkarray = [];
    self.num_perks = 0;
    self.perk_reminder = 0;
    self.perk_count = 0;
    self.perks_given = 0;
    
    self.original_mule_kick_machine_location = undefined;
    self.original_jugger_machine_location = undefined;
    self.original_staminup_machine_location = undefined;
    self.original_speedcola_machine_location = undefined;
    
    self.current_mule_kick_trigger = undefined;
    self.current_jugger_trigger = undefined;
    self.current_staminup_trigger = undefined;
    self.current_speedcola_trigger = undefined;
    
    self.last_mule_kick_purchase_time = 0;
    self.last_jugger_purchase_time = 0;
    self.last_staminup_purchase_time = 0;
    self.last_speedcola_purchase_time = 0;
    
    self.is_purchasing = false;
    self.can_buy_pointcrusher = false;
}

check_proximity_to_machines()
{
    self endon("disconnect");
    self endon("death");
    
    while(true)
    {
        if(self hasPerk("specialty_additionalprimaryweapon") && !self.is_purchasing)
        {
            self check_mule_kick_proximity();
        }
        
        if(self hasPerk("specialty_armorvest") && !self.is_purchasing)
        {
            self check_juggernog_proximity();
        }
        
        if(self hasPerk("specialty_longersprint") && !self.is_purchasing)
        {
            self check_staminup_proximity();
        }
        
        if(self hasPerk("specialty_fastreload") && !self.is_purchasing)
        {
            self check_speedcola_proximity();
        }
        
        if(self hasPerk("specialty_quickrevive") && !self.is_purchasing)
        {
            self check_quickrevive_proximity();
        }
        
        wait 0.2;
    }
}

check_mule_kick_proximity()
{
    if(isDefined(self.original_mule_kick_machine_location))
    {
        if(distance(self.origin, self.original_mule_kick_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_mule_kick_purchase_time >= 200)
            {
                self thread show_multi_mule_kick_prompt();
            }
        }
        else if(isDefined(self.current_mule_kick_trigger))
        {
            self.current_mule_kick_trigger delete();
            self.current_mule_kick_trigger = undefined;
        }
    }
}

check_juggernog_proximity()
{
    if(isDefined(self.original_jugger_machine_location))
    {
        if(distance(self.origin, self.original_jugger_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_jugger_purchase_time >= 200)
            {
                self thread show_multi_juggernog_prompt();
            }
        }
        else if(isDefined(self.current_jugger_trigger))
        {
            self.current_jugger_trigger delete();
            self.current_jugger_trigger = undefined;
        }
    }
}

check_speedcola_proximity()
{
    if(isDefined(self.original_speedcola_machine_location))
    {
        if(distance(self.origin, self.original_speedcola_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_speedcola_purchase_time >= 200)
            {
                self thread show_speedcola_pointcrusher_prompt();
            }
        }
        else if(isDefined(self.current_speedcola_trigger))
        {
            self.current_speedcola_trigger delete();
            self.current_speedcola_trigger = undefined;
        }
    }
}

show_multi_mule_kick_prompt()
{
    self endon("disconnect");
    self endon("death");
    
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing || !self.can_buy_multi_mule)
    {
        return;
    }
    
    if(!isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Multi-Mule Kick [Cost: " + self.mule_kick_price + "]",
            self.original_mule_kick_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_mule_kick_trigger) && 
          self hasPerk("specialty_additionalprimaryweapon") && 
          !self.machine_is_in_use && 
          !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= self.mule_kick_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_mule_kick_trigger))
            {
                self.current_mule_kick_trigger delete();
                self.current_mule_kick_trigger = undefined;
            }
            if(distance(self.origin, self.original_mule_kick_machine_location) <= 70)
            {
                self thread process_multi_mule_kick_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.mule_kick_price)
        {
            if(distance(self.origin, self.original_mule_kick_machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
    
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
    {
        return;
    }
    
    if(!isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Multi-Juggernog [Cost: " + self.jugger_price + "]",
            self.original_jugger_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_jugger_trigger) && 
          self hasPerk("specialty_armorvest") && 
          !self.machine_is_in_use && 
          !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= self.jugger_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_jugger_trigger))
            {
                self.current_jugger_trigger delete();
                self.current_jugger_trigger = undefined;
            }
            if(distance(self.origin, self.original_jugger_machine_location) <= 70)
            {
                self thread process_multi_juggernog_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.jugger_price)
        {
            if(distance(self.origin, self.original_jugger_machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
    
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
    {
        return;
    }
    
    if(!isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Point Crusher [Cost: " + self.pointcrusher_price + "]",
            self.original_speedcola_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_speedcola_trigger) && 
          self hasPerk("specialty_fastreload") && 
          !self.machine_is_in_use && 
          !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= self.pointcrusher_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_speedcola_trigger))
            {
                self.current_speedcola_trigger delete();
                self.current_speedcola_trigger = undefined;
            }
            if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
            {
                self thread process_speedcola_pointcrusher_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.pointcrusher_price)
        {
            if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
    
    if(isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger delete();
        self.current_speedcola_trigger = undefined;
    }
}

process_multi_mule_kick_purchase()
{
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing)
    {
        return;
    }
    
    if(!isDefined(self.original_mule_kick_machine_location) || 
       distance(self.origin, self.original_mule_kick_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.mule_kick_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_additionalprimaryweapon";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self.weapon_limit_counter++;
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.multi_mule_kick_counter++;
    self.mule_kick_price = self.starting_mule_kick_price * self.multi_mule_kick_counter;
    
    self.last_mule_kick_purchase_time = GetTime();

    self iprintln("^1Mule Kick Level " + self.multi_mule_kick_counter + 
                  "\n^2Weapon Limit increased to " + self.weapon_limit_counter);
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

process_multi_juggernog_purchase()
{
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing)
    {
        return;
    }
    
    if(!isDefined(self.original_jugger_machine_location) || 
       distance(self.origin, self.original_jugger_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.jugger_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_jugg";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self.maxhealth += 150;
    self.health = self.maxhealth;
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.multi_juggernog_counter++;
    self.jugger_price = self.starting_jugger_price * self.multi_juggernog_counter;
    
    self.last_jugger_purchase_time = GetTime();
    
    self.hits_counter = int(self.maxhealth / 50);

    self iprintln("^1Juggernog Level " + self.multi_juggernog_counter + 
                  "\n^2Health increased to " + self.maxhealth + 
                  "\n^8Now you resist " + self.hits_counter + " Hits!");
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

process_speedcola_pointcrusher_purchase()
{
    if(!self hasPerk("specialty_fastreload") || self.is_purchasing)
    {
        return;
    }
    
    if(!isDefined(self.original_speedcola_machine_location) || 
       distance(self.origin, self.original_speedcola_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.pointcrusher_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_sleight";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.multi_pointcrusher_counter++;
    self.point_multiplier = self.multi_pointcrusher_counter + 1;
    self.pointcrusher_price = self.starting_pointcrusher_price * self.point_multiplier;
    
    self.last_speedcola_purchase_time = GetTime();
    
    self iprintln("^1Point Crusher Level " + self.multi_pointcrusher_counter + 
                  "\n^2Points Multiplier increased to x" + self.point_multiplier);
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
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
        
        if(self hasPerk("specialty_additionalprimaryweapon"))
        {
            if(!isDefined(self.original_mule_kick_machine_location))
            {
                self.original_mule_kick_machine_location = level.multi_mule_kick_machine.origin;
                self.last_mule_kick_purchase_time = GetTime();
                
                self.can_buy_multi_mule = false;
                wait 1;
                self.can_buy_multi_mule = true;
            }
        }
        
        if(self hasPerk("specialty_armorvest"))
        {
            if(!isDefined(self.original_jugger_machine_location))
            {
                self.original_jugger_machine_location = level.multi_juggernog_machine.origin;
                self.last_jugger_purchase_time = GetTime();
                
                self.can_buy_multi_jugger = false;
                wait 1;
                self.can_buy_multi_jugger = true;
            }
        }
        
        if(self hasPerk("specialty_longersprint"))
        {
            if(!isDefined(self.original_staminup_machine_location))
            {
                self.original_staminup_machine_location = level.multi_staminup_machine.origin;
                self.last_staminup_purchase_time = GetTime();
                
                self.can_buy_jetpack = false;
                wait 1;
                self.can_buy_jetpack = true;
            }
        }
        
        if(self hasPerk("specialty_fastreload"))
        {
            if(!isDefined(self.original_speedcola_machine_location))
            {
                self.original_speedcola_machine_location = level.multi_speedcola_machine.origin;
                self.last_speedcola_purchase_time = GetTime();
                
                self.can_buy_pointcrusher = false;
                wait 1;
                self.can_buy_pointcrusher = true;
            }
        }
        
        if(self hasPerk("specialty_quickrevive"))
        {
            if(!isDefined(self.original_quickrevive_machine_location))
            {
                self.original_quickrevive_machine_location = level.multi_quickrevive_machine.origin;
                self.last_quickrevive_purchase_time = GetTime();
                
                self.can_buy_muscle_milk = false;
                wait 1;
                self.can_buy_muscle_milk = true;
            }
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
            
            if(isDefined(self.current_mule_kick_trigger))
            {
                self.current_mule_kick_trigger delete();
                self.current_mule_kick_trigger = undefined;
            }
        }
        
        if(!self hasPerk("specialty_armorvest"))
        {
            self.multi_juggernog_counter = 1;
            self.jugger_price = self.starting_jugger_price;
            self.original_jugger_machine_location = undefined;
            self.last_jugger_purchase_time = 0;
            
            if(isDefined(self.current_jugger_trigger))
            {
                self.current_jugger_trigger delete();
                self.current_jugger_trigger = undefined;
            }
        }
        
        if(!self hasPerk("specialty_longersprint"))
        {
            self.has_jetpack = false;
            self.original_staminup_machine_location = undefined;
            self.last_staminup_purchase_time = 0;
            
            if(isDefined(self.current_staminup_trigger))
            {
                self.current_staminup_trigger delete();
                self.current_staminup_trigger = undefined;
            }
        }
        
        if(!self hasPerk("specialty_fastreload"))
        {
            self.multi_pointcrusher_counter = 0;
            self.pointcrusher_price = self.starting_pointcrusher_price;
            self.point_multiplier = 1;
            self.original_speedcola_machine_location = undefined;
            self.last_speedcola_purchase_time = 0;
            
            if(isDefined(self.current_speedcola_trigger))
            {
                self.current_speedcola_trigger delete();
                self.current_speedcola_trigger = undefined;
            }
        }
        
        if(!self hasPerk("specialty_quickrevive"))
        {
            self.has_muscle_milk = false;
            self.original_quickrevive_machine_location = undefined;
            self.last_quickrevive_purchase_time = 0;
            
            if(isDefined(self.current_quickrevive_trigger))
            {
                self.current_quickrevive_trigger delete();
                self.current_quickrevive_trigger = undefined;
            }
        }
        
        wait 0.5;
    }
}
custom_get_player_weapon_limit(player)
{
    weapon_limit = 2;
    
    if(player hasPerk("specialty_additionalprimaryweapon"))
    {
        weapon_limit = player.weapon_limit_counter;
    } 
    else 
    {
        weapons = player getWeaponsListPrimaries();
        if(weapons.size > 2)
        {
            player takeWeapon(weapons[2]);
        }
    }
    return weapon_limit;
}

check_staminup_proximity()
{
    if(isDefined(self.original_staminup_machine_location))
    {
        if(distance(self.origin, self.original_staminup_machine_location) <= 70 && !self.machine_is_in_use && !self.has_jetpack)
        {
            current_time = GetTime();
            if(current_time - self.last_staminup_purchase_time >= 200)
            {
                self thread show_staminup_jetpack_prompt();
            }
        }
        else if(isDefined(self.current_staminup_trigger))
        {
            self.current_staminup_trigger delete();
            self.current_staminup_trigger = undefined;
        }
    }
}

show_staminup_jetpack_prompt()
{
    self endon("disconnect");
    self endon("death");
    
    if(!self hasPerk("specialty_longersprint") || self.is_purchasing || self.has_jetpack || !self.can_buy_jetpack)
    {
        return;
    }
    
    if(!isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Exo Suit [Cost: " + self.jetpack_price + "]",
            self.original_staminup_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_staminup_trigger) && 
          self hasPerk("specialty_longersprint") && 
          !self.machine_is_in_use && 
          !self.is_purchasing &&
          !self.has_jetpack)
    {
        if(self useButtonPressed() && self.score >= self.jetpack_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_staminup_trigger))
            {
                self.current_staminup_trigger delete();
                self.current_staminup_trigger = undefined;
            }
            if(distance(self.origin, self.original_staminup_machine_location) <= 70)
            {
                self thread process_staminup_jetpack_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.jetpack_price)
        {
            if(distance(self.origin, self.original_staminup_machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
    
    if(isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger delete();
        self.current_staminup_trigger = undefined;
    }
}

process_staminup_jetpack_purchase()
{
    if(!self hasPerk("specialty_longersprint") || self.is_purchasing || self.has_jetpack)
    {
        return;
    }
    
    if(!isDefined(self.original_staminup_machine_location) || 
       distance(self.origin, self.original_staminup_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.jetpack_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_marathon";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.has_jetpack = true;
    self.last_staminup_purchase_time = GetTime();
    
    self iprintln("^2Exo Suit Acquired!" +
                    "\n^3Now you can Boost yourself!" +
                    "\n^1If you Double Jump and Crouch you can cause an explosion!");
    self thread init_jetpack();
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

init_jetpack()
{
    self endon("disconnect");
    level endon("end_game");
    
    self.sprint_boost = 0;
    self.jump_boost = 0;
    self.slam_boost = 0;
    self.exo_boost = 100;
    self.is_flying_jetpack = 0;
    self.last_boost_time = 0;
    self.boost_cooldown = false;
    self.hover_active = false;
    
    self thread monitor_exo_boost();
    self thread handle_jetpack_movement();
}

handle_jetpack_movement()
{
    self endon("disconnect");
    level endon("end_game");
    
    while(1)
    {
        if(self.has_jetpack)
        {
            if(!self isonground())
            {
                if(self sprintbuttonpressed() || self jumpbuttonpressed())
                {
                    wait_network_frame();
                    continue;
                }
                
                self.sprint_boost = 0;
                self.jump_boost = 0;
                self.slam_boost = 0;
                
                while(!self isonground())
                {
                    if(self.exo_boost >= 20 && self.jump_boost < 1 && self jumpbuttonpressed())
                    {
                        self.is_flying_jetpack = 1;
                        self.jump_boost++;
                        
                        angles = self getplayerangles();
                        direction = anglestoforward((0, angles[1], 0));
                        
                        earthquake(0.22, 0.9, self.origin, 850);
                        self setvelocity((self getvelocity()[0], self getvelocity()[1], 350));
                        
                        self thread land();
                        self.exo_boost -= 20;
                        self thread monitor_exo_boost();
                    }
                    
                    if(self.exo_boost >= 20 && self.sprint_boost < 1 && self sprintbuttonpressed())
                    {
                        self.is_flying_jetpack = 1;
                        self.sprint_boost++;
                        
                        angles = self getplayerangles();
                        direction = anglestoforward(angles);
                        current_vel = self getvelocity();
                        
                        boost_vel = (
                            current_vel[0] + direction[0] * 600,
                            current_vel[1] + direction[1] * 600,
                            current_vel[2]
                        );
                        
                        earthquake(0.22, 0.9, self.origin, 850);
                        self setvelocity(boost_vel);
                        
                        self thread land();
                        self.exo_boost -= 20;
                        self thread monitor_exo_boost();
                    }
                    
                    if(self adsbuttonpressed() && self.exo_boost > 0)
                    {
                        current_vel = self getvelocity();
                        if(current_vel[2] < 0)
                        {
                            hover_vel = (current_vel[0] * 0.95, current_vel[1] * 0.95, current_vel[2] * 0.15);
                            self setvelocity(hover_vel);
                            self.exo_boost = max(0, self.exo_boost - 0.5);
                        }
                    }
                    
                    if(self.exo_boost >= 30 && self.slam_boost < 1 && self.jump_boost > 0 && self stancebuttonpressed())
                    {
                        self.slam_boost++;
                        self setvelocity((self getvelocity()[0], self getvelocity()[1], -200));
                        self thread land();
                        self.exo_boost -= 30;
                        self thread monitor_exo_boost();
                    }
                    
                    wait_network_frame();
                }
                
                if(self.slam_boost > 0)
                {
                    self enableinvulnerability();
                    radiusdamage(self.origin, 200, 3000, 500, self, "MOD_GRENADE_SPLASH");
                    self disableinvulnerability();
                    self playsound("zmb_phdflop_explo");
                    fx = loadfx("explosions/fx_default_explosion");
                    playfx(fx, self.origin);
                }
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
        while(self.exo_boost >= 100)
        {
            wait_network_frame();
        }
        wait 3;
        while(self.exo_boost < 100)
        {
            self.exo_boost = self.exo_boost + 5;
            wait 0.25;
        }
    }
}

land()
{
    self endon("disconnect");
    while(!self isonground())
    {
        wait_network_frame();
    }
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

check_quickrevive_proximity()
{
    if(isDefined(self.original_quickrevive_machine_location))
    {
        if(distance(self.origin, self.original_quickrevive_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_quickrevive_purchase_time >= 200)
            {
                self thread show_muscle_milk_prompt();
            }
        }
        else if(isDefined(self.current_quickrevive_trigger))
        {
            self.current_quickrevive_trigger delete();
            self.current_quickrevive_trigger = undefined;
        }
    }
}

show_muscle_milk_prompt()
{
    self endon("disconnect");
    self endon("death");
    
    if(!self hasPerk("specialty_quickrevive") || self.is_purchasing || self.has_muscle_milk || !self.can_buy_muscle_milk)
    {
        return;
    }
    
    if(!isDefined(self.current_quickrevive_trigger))
    {
        self.current_quickrevive_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Muscle Milk [Cost: " + self.muscle_milk_price + "]",
            self.original_quickrevive_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_quickrevive_trigger) && 
          self hasPerk("specialty_quickrevive") && 
          !self.machine_is_in_use && 
          !self.is_purchasing &&
          !self.has_muscle_milk)
    {
        if(self useButtonPressed() && self.score >= self.muscle_milk_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_quickrevive_trigger))
            {
                self.current_quickrevive_trigger delete();
                self.current_quickrevive_trigger = undefined;
            }
            if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
            {
                self thread process_muscle_milk_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.muscle_milk_price)
        {
            if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                wait 1;
            }
        }
        wait 0.1;
    }
    
    if(isDefined(self.current_quickrevive_trigger))
    {
        self.current_quickrevive_trigger delete();
        self.current_quickrevive_trigger = undefined;
    }
}

process_muscle_milk_purchase()
{
    if(!self hasPerk("specialty_quickrevive") || self.is_purchasing || self.has_muscle_milk)
    {
        return;
    }
    
    if(!isDefined(self.original_quickrevive_machine_location) || 
       distance(self.origin, self.original_quickrevive_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.muscle_milk_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_revive";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.has_muscle_milk = true;
    self.last_quickrevive_purchase_time = GetTime();
    
    self iprintln("^2Muscle Milk Acquired!" +
                    "\n^3Now you can electrocute when you use your melee weapon." +
                    "\n^1Cooldown: 15 seconds");
    self thread monitor_muscle_milk();
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

monitor_muscle_milk()
{
    self endon("disconnect");
    self endon("death");
    
    self thread watch_for_melee();
    
    while(self.has_muscle_milk)
    {
        if(!self hasPerk("specialty_quickrevive"))
        {
            self.has_muscle_milk = false;
            break;
        }
        wait 0.1;
    }
}

watch_for_melee()
{
    self endon("disconnect");
    self endon("death");
    
    while(self.has_muscle_milk)
    {
        if(self meleeButtonPressed() && !self.muscle_milk_cooldown)
        {
            self thread muscle_milk_attack();
        }
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
        if(distance(self.origin, zombie.origin) < 150)
        {
            zombie doDamage(zombie.health + 777, zombie.origin);
        }
    }
    
    self thread muscle_milk_cooldown_timer();
}

muscle_milk_cooldown_timer()
{
    wait 15;
    if(self.has_muscle_milk)
    {
        self iprintln("^2Muscle Milk Ready!");
    }
    self.muscle_milk_cooldown = false;
}
