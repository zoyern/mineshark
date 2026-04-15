ServerEvents.recipes((event) => {
  event.remove({ id: ['create:item_application/railway_casing'], output: 'minecraft:suspicious_sand', output: 'refinedstorage:machine_casing' });

  event.recipes.create.item_application('create:railway_casing', ['minecraft:deepslate', 'unify:gold_sheet']);

  event.recipes.create.pressing('malum:malignant_pewter_plating', 'malum:malignant_pewter_ingot');
  event.recipes.create.pressing('malum:soul_stained_steel_plating', 'malum:soul_stained_steel_ingot');
  event.replaceInput(
    { id: 'create:crafting/materials/sand_paper' }, // Arg 1: the filter
    'minecraft:sand',
    'minecraft:sandstone',
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
});
