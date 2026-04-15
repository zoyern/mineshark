ServerEvents.recipes((event) => {
  event.remove({ output: ['eidolon_repraised:worktable', 'eidolon_repraised:arcane_gold_ingot', 'eidolon_repraised:arcane_gold_nugget', 'eidolon_repraised:arcane_gold_block'] });
  event.shaped('eidolon_repraised:worktable', ['CCC', 'PSP', 'PPP'], { C: 'minecraft:purple_carpet', P: 'malum:runewood_planks', S: 'malum:refined_soulstone' });
  event.replaceInput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_ingot', // Arg 2: the item to replace
    'malum:hallowed_gold_ingot', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceOutput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_ingot', // Arg 2: the item to replace
    'malum:hallowed_gold_ingot', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceInput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_nugget', // Arg 2: the item to replace
    'malum:hallowed_gold_nugget', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceOutput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_nugget', // Arg 2: the item to replace
    'malum:hallowed_gold_nugget', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceOutput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_block', // Arg 2: the item to replace
    'malum:block_of_hallowed_gold', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceInput(
    { mod: 'eidolon_repraised' }, // Arg 1: the filter
    'eidolon_repraised:arcane_gold_block', // Arg 2: the item to replace
    'malum:block_of_hallowed_gold', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
});
