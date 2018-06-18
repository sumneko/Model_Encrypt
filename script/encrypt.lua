package.path = 'script/?.lua;script/?/init.lua'
package.cpath = 'bin/?.dll'

require 'filesystem'
require 'utility'
local storm = require 'ffi.storm'

local temp_dir = fs.path('temp')
local listfile

local index = 10000000
local name_map = {}
local function get_encrypt_name(name)
	local lname = name:lower()
	if not name_map[lname] then
		index = index + 1
		name_map[lname] = ('File%08d'):format(index)
	end
	return name_map[lname]
end

local function save_listfile(map)
	local lines = { listfile }
	for i = 10000001, index do
		lines[#lines+1] = ('File%08d.mdx'):format(i)
		lines[#lines+1] = ('File%08d.mdl'):format(i)
	end
	if not map:save_file('(listfile)', table.concat(lines, '\r\n')) then
		print('[错误]	listfile导入失败')
	end
end

local function rename(map, old, new)
	local res = map:rename_file(old, new)
	return res
end

local function encrypt_portrait(map, name, new_name)
	rename(map, name .. '_portrait.mdl', new_name .. '_portrait.mdl')
	rename(map, name .. '_portrait.mdx', new_name .. '_portrait.mdx')
end

local encrypt_list = {}
local function encrypt_model(map, name, reason)
	name = name:lower()
	if encrypt_list[name] then
		encrypt_list[name] = reason
		return true
	end
	local new_name = get_encrypt_name(name)
	if rename(map, name .. '.mdl', new_name .. '.mdl') or rename(map, name .. '.mdx', new_name .. '.mdx') then
		encrypt_list[name] = reason
		encrypt_portrait(map, name, new_name)
		return true
	end
	return false
end

local function create_log(dir)
	local list = {}
	for name, reason in pairs(encrypt_list) do
		table.insert(list, name)
	end
	table.sort(list)
	for i, name in ipairs(list) do
		list[i] = ('[%s]:	%s'):format(encrypt_list[name], name)
	end
	local success = '加密完成,共加密 ' .. #list .. ' 个模型,用时 ' .. os.clock() .. ' 秒.'
	table.insert(list, 1, success)
	table.insert(list, 2, '若出现模型消失或有模型漏加密的情况,请联系最萌小汐(QQ76196625)')
	table.insert(list, 3, '加密了以下模型,请检查是否有缺失')
	io.save(dir / '模型加密报告.txt', table.concat(list, '\n'))
	print('[成功]	' .. success)
	print('[成功]	查看 "模型加密报告.txt" 了解更多信息')
end

local function read_jass(map)
	local jass = map:load_file('scripts\\war3map.j') or map:load_file('war3map.j')
	if not jass then
		print '[错误]	没有找到脚本'
		return
	end
	
	local new_jass = jass:gsub('([^\\]")([^%c"]*)(%.[mM][dD][lLxX]")', function(str1, name, str2)
		if encrypt_model(map, name:gsub([[\\]], [[\]]), 'war3map.j') then
			return str1 .. get_encrypt_name(name) .. str2
		end
	end)
	
	if map:has_file 'script\\war3map.j' then
		if not map:save_file('scripts\\war3map.j', new_jass) then
			print('[错误]	脚本导入失败')
		end
		return
	elseif map:has_file 'war3map.j' then
		if not map:save_file('war3map.j', new_jass) then
			print('[错误]	脚本导入失败')
		end
		return
	end
	print('[错误]	没有找到脚本')
end

local function read_slk(map, name)
	local slk = map:load_file(name)
	if not slk then
		return
	end

	local new_slk = slk:gsub('(")(%C*)(%.[mM][dD][lLxX]")', function(str1, filename, str2)
		if encrypt_model(map, filename, name) then
			return str1 .. get_encrypt_name(filename) .. str2
		end
	end)
	
	map:save_file(name, new_slk)
end

local function read_txt(map, name)
	local txt = map:load_file(name)
	if not txt then
		return
	end

	local new_txt = txt:gsub('([=,])([^,%c]*)(%.[mM][dD][lLxX])', function(str1, filename, str2)
		if encrypt_model(map, filename, name) then
			return str1 .. get_encrypt_name(filename) .. str2
		end
	end)
	
	map:save_file(name, new_txt)
end

local function read_w3x(map, name)
	local obj = map:load_file(name)
	if not obj then
		return
	end

	local new_obj = obj:gsub('([\0,])(%C-)(%.[mM][dD][lLxX][\0,])', function(str1, filename, str2)
		if encrypt_model(map, filename, name) then
			return str1 .. get_encrypt_name(filename) .. str2
		end
	end)

	map:save_file(name, new_obj)
end

local function read_lua(map)
	if not listfile then
		return
	end

	for dir in listfile:gmatch '%C+' do
		if dir:sub(-4, -1) == '.lua' or dir:sub(-4, -1) == '.ini' then
			local lua = map:load_file(dir)
			if lua then
				new_lua = lua:gsub([[([^\]['"])(%C-)(%.[mM][dD][lLxX]['"])]], function(str1, name, str2)
					if encrypt_model(map, name:gsub([[\\]], [[\]]), dir) then
						return str1 .. get_encrypt_name(name) .. str2
					end
				end)
				new_lua = new_lua:gsub([[([^\]%[%[)(%C-)(%.[mM][dD][lLxX]%]%])]], function(str1, name, str2)
					if encrypt_model(map, name, dir) then
						return str1 .. get_encrypt_name(name) .. str2
					end
				end)
				
				map:save_file(dir, new_lua)
			end
		end
	end
end

local function main()
	if #arg < 1 then
		print '[错误]	请将要加密的地图拖动到bat中'
		return
	end

	-- 保存路径
	local input_dir  = fs.path(arg[1])

	local output_dir = input_dir:parent_path() / fs.path('加密过模型的' .. input_dir:filename():string())

	-- 创建一个临时目录
	fs.create_directories(temp_dir)
	-- 复制一张地图出来
	local success = pcall(fs.copy_file, input_dir, output_dir, true)
	if not success then
		print '[错误]	地图创建失败,可能是地图文件被占用了'
		return
	end

	-- 用storm打开复制出来的地图
	local map = storm.open(output_dir)
	if not map then
		print '[错误]	地图打开失败,可能是使用了特殊的加密手段,或者根本不是地图'
		fs.remove(output_dir)
		fs.remove_all(temp_dir)
		return
	end

	listfile = map:load_file('(listfile)')
	map:remove_file('(listfile)')
	-- 分析指定文件
	read_lua(map)
	read_jass(map)
	read_slk(map, 'units\\abilitybuffdata.slk')
	read_slk(map, 'units\\abilitybuffmetadata.slk')
	read_slk(map, 'units\\abilitydata.slk')
	read_slk(map, 'units\\abilitymetadata.slk')
	read_slk(map, 'units\\abilitysounds.slk')
	read_txt(map, 'units\\aieditordata.txt')
	read_slk(map, 'units\\ambiencesounds.slk')
	read_slk(map, 'units\\animlookups.slk')
	read_slk(map, 'units\\animsounds.slk')
	read_txt(map, 'units\\campaignabilityfunc.txt')
	read_txt(map, 'units\\campaignabilitystrings.txt')
	read_txt(map, 'units\\campaignstrings.txt')
	read_txt(map, 'units\\campaignstrings_exp.txt')
	read_txt(map, 'units\\campaignunitfunc.txt')
	read_txt(map, 'units\\campaignunitstrings.txt')
	read_txt(map, 'units\\campaignupgradefunc.txt')
	read_txt(map, 'units\\campaignupgradestrings.txt')
	read_txt(map, 'units\\chathelp-war3-dede.txt')
	read_txt(map, 'units\\chathelp-war3-enus.txt')
	read_slk(map, 'units\\clifftypes.slk')
	read_txt(map, 'units\\commandfunc.txt')
	read_txt(map, 'units\\commandstrings.txt')
	read_txt(map, 'units\\commonabilityfunc.txt')
	read_txt(map, 'units\\commonabilitystrings.txt')
	read_txt(map, 'units\\config.txt')
	read_txt(map, 'units\\customkeyinfo.txt')
	read_txt(map, 'units\\customkeyssample.txt')
	read_txt(map, 'units\\d2xtrailercaptions.txt')
	read_slk(map, 'units\\destructabledata.slk')
	read_slk(map, 'units\\destructablemetadata.slk')
	read_slk(map, 'units\\dialogsounds.slk')
	read_txt(map, 'units\\directx end user eula.txt')
	read_slk(map, 'units\\doodadmetadata.slk')
	read_slk(map, 'units\\doodads.slk')
	read_slk(map, 'units\\eaxdefs.slk')
	read_slk(map, 'units\\environmentsounds.slk')
	read_txt(map, 'units\\eula.txt')
	read_txt(map, 'units\\ghostcaptions.txt')
	read_txt(map, 'units\\helpstrings.txt')
	read_txt(map, 'units\\humanabilityfunc.txt')
	read_txt(map, 'units\\humanabilitystrings.txt')
	read_txt(map, 'units\\humaned.txt')
	read_txt(map, 'units\\humanop.txt')
	read_txt(map, 'units\\humanunitfunc.txt')
	read_txt(map, 'units\\humanunitstrings.txt')
	read_txt(map, 'units\\humanupgradefunc.txt')
	read_txt(map, 'units\\humanupgradestrings.txt')
	read_txt(map, 'units\\iconindex_bel.txt')
	read_txt(map, 'units\\iconindex_def.txt')
	read_txt(map, 'units\\iconindex_def2.txt')
	read_txt(map, 'units\\introx.txt')
	read_txt(map, 'units\\itemabilityfunc.txt')
	read_txt(map, 'units\\itemabilitystrings.txt')
	read_slk(map, 'units\\itemdata.slk')
	read_txt(map, 'units\\itemfunc.txt')
	read_txt(map, 'units\\itemstrings.txt')
	read_txt(map, 'units\\license.txt')
	read_slk(map, 'units\\lightningdata.slk')
	read_txt(map, 'units\\local.txt')
	read_txt(map, 'units\\machelpstrings.txt')
	read_txt(map, 'units\\macstrings.txt')
	read_txt(map, 'units\\macworldeditstrings.txt')
	read_slk(map, 'units\\midisounds.slk')
	read_txt(map, 'units\\miscdata.txt')
	read_txt(map, 'units\\miscgame.txt')
	read_slk(map, 'units\\miscmetadata.slk')
	read_txt(map, 'units\\miscui.txt')
	read_txt(map, 'units\\neutralabilityfunc.txt')
	read_txt(map, 'units\\neutralabilitystrings.txt')
	read_txt(map, 'units\\neutralunitfunc.txt')
	read_txt(map, 'units\\neutralunitstrings.txt')
	read_txt(map, 'units\\neutralupgradefunc.txt')
	read_txt(map, 'units\\neutralupgradestrings.txt')
	read_txt(map, 'units\\newaccount-dede.txt')
	read_txt(map, 'units\\newaccount-enus.txt')
	read_txt(map, 'units\\nightelfabilityfunc.txt')
	read_txt(map, 'units\\nightelfabilitystrings.txt')
	read_txt(map, 'units\\nightelfed.txt')
	read_txt(map, 'units\\nightelfunitfunc.txt')
	read_txt(map, 'units\\nightelfunitstrings.txt')
	read_txt(map, 'units\\nightelfupgradefunc.txt')
	read_txt(map, 'units\\nightelfupgradestrings.txt')
	read_slk(map, 'units\\notused_unitdata.slk')
	read_slk(map, 'units\\notused_unitui.slk')
	read_slk(map, 'units\\old_unitcombatsounds.slk')
	read_txt(map, 'units\\orcabilityfunc.txt')
	read_txt(map, 'units\\orcabilitystrings.txt')
	read_txt(map, 'units\\orced.txt')
	read_txt(map, 'units\\orcunitfunc.txt')
	read_txt(map, 'units\\orcunitstrings.txt')
	read_txt(map, 'units\\orcupgradefunc.txt')
	read_txt(map, 'units\\orcupgradestrings.txt')
	read_txt(map, 'units\\outrox.txt')
	read_txt(map, 'units\\patch.txt')
	read_slk(map, 'units\\portraitanims.slk')
	read_slk(map, 'units\\skinmetadata.slk')
	read_slk(map, 'units\\spawndata.slk')
	read_slk(map, 'units\\splatdata.slk')
	read_txt(map, 'units\\startupstrings.txt')
	read_slk(map, 'units\\t_spawndata.slk')
	read_slk(map, 'units\\t_splatdata.slk')
	read_txt(map, 'units\\telemetry.txt')
	read_txt(map, 'units\\termsofservice-dede.txt')
	read_txt(map, 'units\\termsofservice-enus.txt')
	read_slk(map, 'units\\terrain.slk')
	read_txt(map, 'units\\textures.txt')
	read_txt(map, 'units\\tipstrings.txt')
	read_txt(map, 'units\\triggerdata.txt')
	read_txt(map, 'units\\triggerstrings.txt')
	read_txt(map, 'units\\tutorialin.txt')
	read_txt(map, 'units\\tutorialop.txt')
	read_slk(map, 'units\\ubersplatdata.slk')
	read_slk(map, 'units\\uisounds.slk')
	read_txt(map, 'units\\undeadabilityfunc.txt')
	read_txt(map, 'units\\undeadabilitystrings.txt')
	read_txt(map, 'units\\undeaded.txt')
	read_txt(map, 'units\\undeadunitfunc.txt')
	read_txt(map, 'units\\undeadunitstrings.txt')
	read_txt(map, 'units\\undeadupgradefunc.txt')
	read_txt(map, 'units\\undeadupgradestrings.txt')
	read_slk(map, 'units\\unitabilities.slk')
	read_slk(map, 'units\\unitacksounds.slk')
	read_slk(map, 'units\\unitbalance.slk')
	read_slk(map, 'units\\unitcombatsounds.slk')
	read_slk(map, 'units\\unitdata.slk')
	read_txt(map, 'units\\uniteditordata.txt')
	read_txt(map, 'units\\unitglobalstrings.txt')
	read_slk(map, 'units\\unitmetadata.slk')
	read_slk(map, 'units\\unitui.slk')
	read_slk(map, 'units\\unitweapons.slk')
	read_slk(map, 'units\\upgradedata.slk')
	read_slk(map, 'units\\upgradeeffectmetadata.slk')
	read_slk(map, 'units\\upgrademetadata.slk')
	read_txt(map, 'units\\war3mapextra.txt')
	read_txt(map, 'units\\war3mapmisc.txt')
	read_txt(map, 'units\\war3mapskin.txt')
	read_txt(map, 'units\\war3skins.txt')
	read_txt(map, 'units\\war3x.txt')
	read_slk(map, 'units\\water.slk')
	read_slk(map, 'units\\weather.slk')
	read_txt(map, 'units\\worldeditdata.txt')
	read_txt(map, 'units\\worldeditgamestrings.txt')
	read_txt(map, 'units\\worldeditlayout.txt')
	read_txt(map, 'units\\worldeditlicense.txt')
	read_txt(map, 'units\\worldeditstartupstrings.txt')
	read_txt(map, 'units\\worldeditstrings.txt')
	read_txt(map, 'units\\wowtrailercaptions.txt')
	read_w3x(map, 'war3map.w3u')
	read_w3x(map, 'war3map.w3t')
	read_w3x(map, 'war3map.w3b')
	read_w3x(map, 'war3map.w3d')
	read_w3x(map, 'war3map.w3a')
	read_w3x(map, 'war3map.w3h')
	read_w3x(map, 'war3map.w3q')

	save_listfile(map)

	map:close()
	--fs.remove_all(temp_dir)

	-- 创建报告
	create_log(input_dir:parent_path())
end

main()
