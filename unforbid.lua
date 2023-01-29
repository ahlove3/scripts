-- Unforbid all items

local argparse = require('argparse')

local function unforbid_all(include_unreachable, include_underwater, quiet)
    if not quiet then print('Unforbidding all items...') end

    local count = 0
    for _, item in ipairs(df.global.world.items.all) do
        if item.flags.forbid then
            local block = dfhack.maps.getTileBlock(item.pos)
            local tile = dfhack.maps.getTileFlags(item.pos)

            if block then
                local walkable = block.walkable[item.pos.x % 16][item.pos.y % 16]

                if not include_unreachable and walkable == 0 then
                    if not quiet then print(('  unreachable: %s (skipping)'):format(item)) end
                    goto skipitem
                end

                if not include_underwater and (tile.liquid_type == false and tile.flow_size > 3) then
                    if not quiet then print(('  underwater: %s (skipping)'):format(item)) end
                    goto skipitem
                end
            end

            if not quiet then print(('  unforbid: %s'):format(item)) end
            item.flags.forbid = false
            count = count + 1

            ::skipitem::
        end
    end

    if not quiet then print(('%d items unforbidden'):format(count)) end
end

-- let the common --help parameter work, even though it's undocumented
local options, args = {
    help = false,
    quiet = false,
    include_unreachable = false,
    include_underwater = false
}, { ... }

local positionals = argparse.processArgsGetopt(args, {
    { 'h', 'help', handler = function() options.help = true end },
    { 'q', 'quiet', handler = function() options.quiet = true end },
    { 'u', 'include-unreachable', handler = function() options.include_unreachable = true end },
    { 'w', 'include-underwater', handler = function() options.include_underwater = true end },
})

if positionals[1] == nil or positionals[1] == 'help' or options.help then
    print(dfhack.script_help())
end

if positionals[1] == 'all' then
    unforbid_all(options.include_unreachable, options.include_underwater, options.quiet)
end
