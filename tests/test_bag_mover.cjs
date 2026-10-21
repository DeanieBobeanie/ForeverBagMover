const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.resolve(__dirname, '..');
const dependency = name => require(name);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = dependency('fengari');
const source = fs.readFileSync(process.argv[2] || path.join(root, 'ForeverBagMover/ForeverBagMover.lua'), 'utf8');
dependency('luaparse').parse(source, { luaVersion: '5.1' });
const toc = fs.readFileSync(path.join(root, 'ForeverBagMover/ForeverBagMover.toc'), 'utf8');
assert(toc.includes('## SavedVariablesPerCharacter: ForeverBagMoverDB'));
assert(toc.includes('## Interface: 16001'));
let state;
function run(text) {
  if (lauxlib.luaL_dostring(state, to_luastring(text)) !== lua.LUA_OK) {
    throw Error(to_jsstring(lua.lua_tostring(state, -1)));
  }
}
const test = fs.readFileSync(path.join(__dirname, 'test_bag_mover.lua'), 'utf8').split('-- LOAD ADDON HERE');
const loadAddon = 'assert(load([====[' + source + ']====]))("ForeverBagMover")';
for (const mode of ['modern', 'legacy']) {
state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
run('escapeMode="' + mode + '"');
run(test[0] + '\n' + loadAddon + '\n' + test[1] + '\n' + loadAddon + `
controller=frames[#frames]
event('ADDON_LOADED','ForeverBagMover')
event('PLAYER_LOGIN')
near(ContainerFrameCombinedBags:GetLeft()*0.8,160)
assert(ForeverBagMoverOptions.checks.locked:GetChecked())
assert(ForeverBagMoverDB.locked)
assert(ForeverBagMoverDB.handleSide=='bottom')
near(ContainerFrameCombinedBags:GetTop()*0.8,600)
assert(ForeverBagMoverDB.escapeCloses and not ForeverBagMoverDB.openReagent)
assert(pressEscape() and not ContainerFrameCombinedBags:IsShown())
`);
lua.lua_close(state);
}
console.log('PASS: Lua 5.1 syntax, manifest, saved positions, reload, reused frames, combined/separate bags, combat relayout and reopening, interrupted drags at both handle positions and UI scales, restricted-frame guards, locking, reset, screen bounds, gear options, saved preferences, both Escape modes, reagent opening and cancellation, explicit closing, partial selections and vendors, and guards against custom Escape registration or direct bag-close calls.');
