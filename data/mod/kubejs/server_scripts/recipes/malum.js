ServerEvents.recipes((event) => {
  event.remove({ id: 'betterend:eternal_crystal' });

  event.recipes.malum.void_favor(
    'minecraft:diamond', //Input
    'gateways:gate_pearl[gateways:gateway="gateways:basic/enderman"]', //Result
  );
  event.replaceInput({ id: 'malum:malignant_pewter_ingot' }, '#c:ingots/iron', 'eidolon_repraised:pewter_ingot');

  event.recipes.malum.spirit_infusion(
    'minecraft:echo_shard', //Input
    'betterend:eternal_crystal', //Result
    ['16x arcane'], //Spirits
    ['128x betterend:crystal_shards', 'minecraft:end_crystal'], //Additional Inputs, Defaults to []
  );

  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:volcanite_shard', ['64x infernal'], ['64x ars_nouveau:fire_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:ice_shard', ['64x aqueous'], ['64x kubejs:ice_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:divinite_shard', ['64x sacred'], ['64x ars_nouveau:manipulation_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:floralite_shard', ['64x earthen'], ['64x ars_nouveau:earth_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:voltite_shard', ['64x aerial'], ['64x ars_nouveau:air_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:voidstone_shard', ['64x eldritch'], ['64x ars_nouveau:abjuration_essence']);
  event.recipes.malum.spirit_infusion('irons_spellbooks:divine_soulshard', 'crystal_chronicles:hemalite_shard', ['64x wicked'], ['64x ars_elemental:anima_essence']);
});
