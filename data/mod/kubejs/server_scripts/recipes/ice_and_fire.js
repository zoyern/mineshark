ServerEvents.recipes((event) => {
  (event.remove({ id: 'iceandfire:dragonforge/dragonsteel_lightning_ingot' }), event.remove({ id: 'iceandfire:dragonforge/dragonsteel_fire_ingot' }), event.remove({ id: 'iceandfire:dragonforge/dragonsteel_ice_ingot' }));
  event.remove({
    output: [
      'iceandfire:dragonforge_lightning_core_disabled',
      'iceandfire:dragonforge_ice_core_disabled',
      'iceandfire:dragonforge_fire_core_disabled',
      'iceandfire:dragonforge_lightning_input',
      'iceandfire:dragonforge_fire_input',
      'iceandfire:dragonforge_ice_input',
      'iceandfire:summoning_crystal_ice',
      'iceandfire:summoning_crystal_fire',
      'iceandfire:summoning_crystal_lightning',
    ],
  });
});

function addDragonforgeRecipes(event) {
  const types = [
    {
      dragonType: 'ice',
      blood: 'iceandfire:ice_dragon_blood',
      result: 'iceandfire:dragonsteel_ice_ingot',
    },
    {
      dragonType: 'fire',
      blood: 'iceandfire:fire_dragon_blood',
      result: 'iceandfire:dragonsteel_fire_ingot',
    },
    {
      dragonType: 'lightning',
      blood: 'iceandfire:lightning_dragon_blood',
      result: 'iceandfire:dragonsteel_lightning_ingot',
    },
  ];

  types.forEach((t) => {
    event.custom({
      type: 'iceandfire:dragonforge',
      dragonType: t.dragonType,
      cookTime: 1000,
      input: {
        item: 'irons_spellbooks:mithril_ingot',
      },
      blood: {
        item: t.blood,
      },
      result: {
        id: t.result,
        item: t.result,
      },
    });
  });
}

ServerEvents.recipes(addDragonforgeRecipes);
ServerEvents.recipes((event) => {
  event.recipes.create.mechanical_crafting('iceandfire:dragonforge_lightning_core_disabled', [' B B ', 'BSFSB', ' AHA ', 'BSDSB', ' B B '], {
    H: 'iceandfire:lightning_dragon_heart',
    B: 'iceandfire:dragonforge_lightning_brick',
    F: 'cataclysm:void_core',
    S: 'create:sturdy_sheet',
    A: 'malum:soul_stained_steel_plating',
    D: 'malum:paracausal_flame',
  });

  event.recipes.create.mechanical_crafting('iceandfire:dragonforge_ice_core_disabled', [' B B ', 'BSFSB', ' AHA ', 'BSDSB', ' B B '], {
    H: 'iceandfire:ice_dragon_heart',
    B: 'iceandfire:dragonforge_ice_brick',
    F: 'cataclysm:void_core',
    S: 'create:sturdy_sheet',
    A: 'malum:soul_stained_steel_plating',
    D: 'malum:paracausal_flame',
  });

  event.recipes.create.mechanical_crafting('iceandfire:dragonforge_fire_core_disabled', [' B B ', 'BSFSB', ' AHA ', 'BSDSB', ' B B '], {
    H: 'iceandfire:fire_dragon_heart',
    B: 'iceandfire:dragonforge_fire_brick',
    F: 'cataclysm:void_core',
    S: 'create:sturdy_sheet',
    A: 'malum:soul_stained_steel_plating',
    D: 'malum:paracausal_flame',
  });

  event.recipes.create.item_application('iceandfire:dragonforge_fire_input', ['iceandfire:dragonforge_fire_brick', 'malum:anomalous_design']);
  event.recipes.create.item_application('iceandfire:dragonforge_ice_input', ['iceandfire:dragonforge_ice_brick', 'malum:anomalous_design']);
  event.recipes.create.item_application('iceandfire:dragonforge_lightning_input', ['iceandfire:dragonforge_lightning_brick', 'malum:anomalous_design']);
});
