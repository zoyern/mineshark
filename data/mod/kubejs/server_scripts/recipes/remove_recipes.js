ServerEvents.recipes((event) => {
  const itemsToRemove = [
    'simplyswords:runic_longsword',
    'simplyswords:runic_twinblade',
    'simplyswords:runic_rapier',
    'simplyswords:runic_cutlass',
    'simplyswords:runic_greataxe',
    'simplyswords:runic_chakram',
    'simplyswords:runic_greathammer',
    'simplyswords:runic_scythe',
    'simplyswords:runic_sai',
    'simplyswords:runic_glaive',
    'simplyswords:runic_warglaive',
    'simplyswords:runic_halberd',
    'simplyswords:runic_spear',
    'simplyswords:runic_katana',
    'simplyswords:runic_claymore',
    'simplyswords:tainted_relic',
    'simplyswords:righteous_relic',
    'simplyswords:sunfire',
    'simplyswords:harbinger',
    'simplyswords:waking_lichblade',
    'simplyswords:awakened_lichblade',
    'simplyswords:runefused_gem',
    'simplyswords:netherfused_gem',
    'crystal_chronicles:evocation_twinblade',
  ];

  console.log(`[RecipeRemoval] Removing recipes with inputs/outputs:`);
  itemsToRemove.forEach((item) => {
    event.remove({ output: item });
    event.remove({ input: item });

    console.log(` - Removed recipes involving: ${item}`);
  });
  const itemsToRemove_byid = ['mynethersdelight:cutting/skoglin_trophy', 'mynethersdelight:cutting/cutting/hoglin_hide', 'createaddition:crushing/tuff_recycling', 'naturescompass:natures_compass', 'malum:malignant_pewter_plating', 'malum:soul_stained_steel_plating'];

  itemsToRemove_byid.forEach((item) => {
    event.remove({ id: item });
    console.log(` - Removed recipes involving: ${item}`);
  });
});
